struct EditorMode
  name::String
end

const MODE_NORMAL = EditorMode("normal")

mutable struct Editor
  mode :: EditorMode
  frame :: Int
  view_3d    :: Union{Nothing, View}
  view_top   :: Union{Nothing, View}
  view_cross :: Union{Nothing, View}
  j :: Tuple{Int,Int,Int}
  cell_mesh :: Union{Nothing, StaticMesh}
  cell_cut :: CellCut
  cell_normals
  cell_normals_at
  computing_normals :: Bool

  Editor() = new(
    MODE_NORMAL,
    0,
    nothing,
    nothing,
    nothing,
    (7,7,14),
    nothing,
    CellCut(mm*500f0*Vec3f(6.5, 6.5, 13.5), 0),
    nothing,
    nothing,
    false,
  )
end

const CELL_SIDE = 500f0 * mm

init!(ed::Editor) = begin
  # Ugh..
  focus_on_cell!(the_scene.scanvol, the_editor.j...)
  println("Loading textures into GPU...")
  load_textures(the_scene.scanvol)
  println("Loaded into GPU.")

  dims = dimensions(the_scene.scanvol)
  p0, p1 = cell_position(the_scene.scanvol)
  c = (p0 + p1)/2f0

  p = p1 + Vec3f(3.94)
  ed.view_3d = View("3D View", PerspectiveCamera(p, p0, Vec3f(0f0, 0f0, 1f0), 1))

  n = Vec3f(0, 0, 2f0 * CELL_SIDE)
  ed.view_top = View("Top View", OrthographicCamera(
    c + n, -n, Vec3f(0f0, 1f0,  0f0), CELL_SIDE, CELL_SIDE))

  n = Vec3f(0, 2f0 * CELL_SIDE, 0)
  ed.view_cross = View("Cross View", OrthographicCamera(
    c + n, -n, Vec3f(0f0, 0f0, 1f0), CELL_SIDE, CELL_SIDE))

  offset = Vec3f(0.001)
  ed.cell_mesh = StaticBoxMesh(p0+offset, p1-offset)

  nothing
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
  angle = Ref(180f0 * ed.cell_cut.θ / π)
  DragFloat("Cut angle", angle, 1f0, -180f0, 180f0)
  ed.cell_cut.θ = π * angle[] / 180f0
  p0, p1 = cell_position(the_scene.scanvol)
  c = (p0 + p1)/2f0
  n = 2f0 * CELL_SIDE * Vec3f(sin(ed.cell_cut.θ), -cos(ed.cell_cut.θ), 0)
  ed.view_cross.camera.p = c + n
  ed.view_cross.camera.n = -n
  CImGui.Text("Camera p: $(ed.view_cross.camera.p)")
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


# Commands #####################################################################

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
