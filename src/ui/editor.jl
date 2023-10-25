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
  ed.view_3d = View("3D View", PerspectiveCamera(p1 + 4*E1, p0, Ez, 1))
  n = 2f0 * cell_size * Ez
  ed.view_top = View("Top View", OrthographicCamera(c + n, -n, Ey, cell_size, cell_size))
  n = 2f0 * cell_size * Ey
  ed.view_cross = View("Cross View", OrthographicCamera(c + n, -n, Ez, cell_size, cell_size))
  # update_cross_camera!(ed, ed.cell_cut.p, 0)
end

all_views(ed::Editor) =
  [ed.view_3d, ed.view_top, ed.view_cross]

update!(ed::Editor) = begin
  if ed.frame % 60 == 0
    for view = all_views(ed)
      reload!(view.shader)
    end
  end
  ed.frame += 1
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
  # update_cross_camera!(ed, ed.cell_cut.p, θ)

  if !ed.computing_normals
    if CImGui.Button("Compute Normals")
      compute_normals!()
    end
  else
    CImGui.Text("Computing Normals... This will take a while.")
  end

  CImGui.End()

  # TODO: It seems like creating the VAOs in advance doesn't work but doing
  # so here while the FBO is bound does. Figure out why and how to handle it.
  draw_on_view!(ed.view_3d) do shader, width, height
    draw!(ed.cell_cut, shader)
  end
  draw_on_view!(ed.view_cross) do shader, width, height
    draw!(ed.cell_cut, shader)
  end
  draw_on_view!(ed.view_top) do shader, width, height
    draw!(ed.cell_mesh, shader)
  end
  glBindFramebuffer(GL_FRAMEBUFFER, 0)
  nothing
end

update_cell_cut!(ed::Editor, p::Vec3, θ::Float32) = begin
  ed.cell_cut.p = p
  ed.cell_cut.n = Vec3f(cos(θ), sin(θ), 0)
  nothing
end

update_cross_camera!(ed::Editor, p::Vec3, θ::Float32) = begin
  p0, p1 = cell_range_mm(the_scan, ed.j...)
  c = (p0 + p1)/2f0
  n = cell_mm(the_scan) * Vec3f(sin(θ), -cos(θ), 0)
  ed.view_cross.camera.p = c + 2*n
  ed.view_cross.camera.n = -2*n
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


# Key bindings #################################################################

struct KeyBinding
  key::Int32
  mods::Int32
end

const KeyMap = Dict{KeyBinding, Function}

KEYMAP_NORMAL = KeyMap(
  # KeyBinding(GLFW_KEY_R, 0) => reload!,
)

on_key!(ed::Editor, window::Ptr{GLFWwindow}, key::Cint, scancode::Cint, action::Cint, mods::Cint)::Cvoid = begin
  if action == GLFW_PRESS
    if ed.mode == MODE_NORMAL
      f = get(KEYMAP_NORMAL, KeyBinding(key, mods), nothing)
      !isnothing(f) && f()
    end
  end
  nothing
end
