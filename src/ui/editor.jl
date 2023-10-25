struct EditorMode
  name::String
end

const MODE_NORMAL = EditorMode("normal")

mutable struct Editor
  mode :: EditorMode

  view_3d    :: Union{Nothing, View}
  view_top   :: Union{Nothing, View}
  view_cross :: Union{Nothing, View}

  j :: Tuple{Int,Int,Int}

  cell_cut :: Plane
  cell_mesh :: Union{Nothing, StaticMesh}
  cell_normals
  cell_normals_at

  frame :: Int
  computing_normals :: Bool

  Editor(j::Tuple{Int, Int, Int}) =
    new(
      MODE_NORMAL, # mode
      nothing, nothing, nothing, # views
      j,
      Plane(cell_position_mm(the_scan, (j .+ 0.5)...), Ey),
      nothing, # cell_mesh
      nothing, # cell_normals
      nothing, # cell_normals_at
      0,       # frame
      false,   # computing_normals
    )
end


init!(ed::Editor) = begin
  focus_on_cell!(the_scene.scanvol, the_editor.j...)
  # println("Loading textures into GPU...")
  load_textures(the_scene.scanvol)
  # println("Loaded into GPU.")

  init_views!(ed::Editor)

  p0, p1 = cell_range_mm(the_scan, ed.j...)
  offset = Vec3f(px_mm(the_scan))
  ed.cell_mesh = StaticBoxMesh(p0+offset, p1-offset)

  nothing
end

init_views!(ed::Editor) = begin
  cell_size = cell_mm(the_scan)
  p0, p1 = cell_range_mm(the_scan, ed.j...)
  c = (p0 + p1)/2f0
  ed.view_3d = View("3D View", PerspectiveCamera(p1 + 2*Vec3f(1, 0.9, 0.7), p0, Ez, 1))
  n = 2f0 * cell_size * Ez
  ed.view_top = View("Top View", OrthographicCamera(c + n, -n, Ey, cell_size, cell_size))
  n = 2f0 * cell_size * Ey
  ed.view_cross = View("Cross View", OrthographicCamera(c + n, -n, Ez, cell_size, cell_size))
end

all_views(ed::Editor) =
  [ed.view_3d, ed.view_top, ed.view_cross]

update!(ed::Editor) = begin
  ed.frame += 1
  if ed.frame % 60 == 0
    for view = all_views(ed)
      reload!(view.shader)
    end
  end

  if ed.mode == MODE_NORMAL
    for (kb, f) = KEYMAP_NORMAL
      if kb.continuous
        if CImGui.IsKeyDown(kb.key) # && CImGui.IsKeyDown(kb.mods) # TODO: mods
          f()
        end
      end
    end
  end

  # check_bgtask(ed)
  nothing
end

draw!(ed::Editor) = begin
  LibCImGui.igDockSpaceOverViewport(C_NULL, ImGuiDockNodeFlags_PassthruCentralNode, C_NULL)

  CImGui.BeginMainMenuBar()
    if CImGui.BeginMenu("File")
      CImGui.MenuItem("New")
      CImGui.MenuItem("Open")
      CImGui.MenuItem("Save")
      CImGui.MenuItem("Save As...")
      CImGui.EndMenu()
    end
    if CImGui.BeginMenu("Edit")
      CImGui.MenuItem("Edit")
      CImGui.EndMenu()
    end
    if CImGui.BeginMenu("Help")
      CImGui.MenuItem("Help")
      CImGui.EndMenu()
    end
  CImGui.EndMainMenuBar()

  CImGui.Begin("Info")
  CImGui.Text("Cell: $(ed.j)")
  CImGui.Text("GPU: $(the_gpu_info.renderer_string)")
  CImGui.Text("GPU max texture buffer size: $(the_gpu_info.max_texture_buffer_size / 1024^2) MB")
  CImGui.End()

  CImGui.Begin("Controls")

  angle = Ref(180f0 * acos(ed.cell_cut.n[1]) / π)
  DragFloat("Cut angle", angle, 1f0, -180f0, 180f0)
  θ = π * angle[] / 180f0

  update_cell_cut!(ed, ed.cell_cut.p, θ)
  update_cross_camera!(ed)

  if !ed.computing_normals
    if CImGui.Button("Compute Normals")
      compute_normals!()
    end
  else
    CImGui.Text("Computing Normals... This will take a while.")
  end

  CImGui.End()

  l = cell_mm(the_scan)/9f0
  p0, p1 = cell_range_mm(the_scan, 7, 7, 14)
  p0 += px_mm(the_scan)*Ez
  p1 += px_mm(the_scan)*Ez
  gm = GridSheetFromRange(p0, p0 + cell_mm(the_scan)*Vec3f(1,1,0), Ex, l)

  gm_cut = GridSheetFromCenter(ed.cell_cut.p, ed.cell_cut.n, Ez, l, 10, 10)


  # TODO: It seems like creating the VAOs in advance doesn't work but doing
  # so here while the FBO is bound does. Figure out why and how to handle it.
  draw_on_view!(ed.view_3d) do shader, width, height
    # draw!(ed.cell_cut, shader)
    draw!(gm_cut, shader)
    draw!(gm, shader)
  end
  draw_on_view!(ed.view_cross) do shader, width, height
    draw!(gm_cut, shader)
    draw!(gm, shader)
  end
  draw_on_view!(ed.view_top) do shader, width, height
    draw!(gm, shader)
  end
  glBindFramebuffer(GL_FRAMEBUFFER, 0)
  nothing
end

update_cell_cut!(ed::Editor, p::Vec3, θ::Float32) = begin
  ed.cell_cut.p = p
  ed.cell_cut.n = Vec3f(cos(θ), sin(θ), 0)
  nothing
end

update_cross_camera!(ed::Editor) = begin
  ed.view_cross.camera.p = ed.cell_cut.p + 2*ed.cell_cut.n
  ed.view_cross.camera.n = -ed.cell_cut.n
  nothing
end



compute_normals!() = begin
  the_editor.computing_normals = true
  compute_normals_job() = begin
    try
      N, P = estimate_normals(the_scene.scanvol.cell)
      the_editor.cell_normals = N
      the_editor.cell_normals_at = P
    catch e
      @error "Error computing normals!" exception=e
      Base.show_backtrace(stderr, catch_backtrace())
    finally
      the_editor.computing_normals = false
    end
  end
  Threads.@spawn compute_normals_job()
end

load_scene_scan_volume!() = begin
  # load_small!(the_scene.scanvol) # TODO
  nothing
end

# check_bgtask(ed::Editor) = begin
#   if !isnothing(ed.bgtask)
#     if istaskdone(ed.bgtask)
#       println("Loading textures into GPU...")
#       load_textures(the_scene.scanvol)
#       println("Loaded into GPU.")
#       ed.bgtask = nothing
#     elseif istaskfailed(ed.bgtask)
#       println("Background task failed.")
#       ed.bgtask = nothing
#     end
#   end
# end

toggle_wireframe!(ed::Editor) = begin
  ed.view_3d.wireframe = !ed.view_3d.wireframe
end


rotate_cell_cut!(ed::Editor, dθ::Float32) = begin
  ed.cell_cut.n = rotate(ed.cell_cut.n, Ez, dθ)
end

move_cell_cut!(ed::Editor, left::Float32, fwd::Float32) = begin
  n = normalize(ed.cell_cut.n)
  ed.cell_cut.p += fwd*n + left*cross(n, Ez)
end

# Key bindings #################################################################

struct KeyBinding
  key::Int32
  mods::Int32
  continuous::Bool
end

KeyBinding(key, mods) =
  KeyBinding(key, mods, false)

const KeyMap = Dict{KeyBinding, Function}

KEYMAP_NORMAL = KeyMap(
  KeyBinding(GLFW_KEY_W, GLFW_MOD_ALT)   => () -> toggle_wireframe!(the_editor),

  KeyBinding(GLFW_KEY_S, 0, true)        => () -> move_cell_cut!(the_editor, 0f0, +0.01f0),
  KeyBinding(GLFW_KEY_W, 0, true)        => () -> move_cell_cut!(the_editor, 0f0, -0.01f0),
  KeyBinding(GLFW_KEY_A, 0, true)        => () -> move_cell_cut!(the_editor, -0.01f0, 0f0),
  KeyBinding(GLFW_KEY_D, 0, true)        => () -> move_cell_cut!(the_editor, +0.01f0, 0f0),
  KeyBinding(GLFW_KEY_Q, 0, true)        => () -> rotate_cell_cut!(the_editor, -0.01f0),
  KeyBinding(GLFW_KEY_E, 0, true)        => () -> rotate_cell_cut!(the_editor, +0.01f0),
)

on_key!(ed::Editor, window::Ptr{GLFWwindow}, key::Cint, scancode::Cint, action::Cint, mods::Cint)::Cvoid = begin
  if action == GLFW_PRESS || action == GLFW_REPEAT
    if ed.mode == MODE_NORMAL 
      f = get(KEYMAP_NORMAL, KeyBinding(key, mods, false), nothing)
      !isnothing(f) && f()
    end
  end
  nothing
end
