struct EditorMode
  name::String
end

const MODE_NORMAL = EditorMode("normal")

mutable struct Editor
  mode :: EditorMode
  frame :: Int
  views :: Vector{View}
  j :: Tuple{Int,Int,Int}
  cell_mesh :: Union{Nothing, StaticMesh}

  Editor() = new(
    MODE_NORMAL,
    0,
    View[],
    (7,7,14),
    nothing
  )
end

init!(ed::Editor) = begin
  # Ugh..
  focus_on_cell!(the_scene.scanvol, the_editor.j...)
  println("Loading textures into GPU...")
  load_textures(the_scene.scanvol)
  println("Loaded into GPU.")

  dims = dimensions(the_scene.scanvol)
  p0, p1 = cell_position(the_scene.scanvol)

  # camera = PerspectiveCamera(dims, 0.5f0 * dims, Vec3f(0f0, 0f0, 1f0), 1))
  p = p1 + Vec3f(3.94)
  camera = PerspectiveCamera(p, p0, Vec3f(0f0, 0f0, 1f0), 1)
  push!(ed.views, View("3D View", camera))

  # push!(ed.views, View("Front View", the_scene.camera)) # TODO: camera
  # push!(ed.views, View("Cross View", the_scene.camera)) # TODO: camera

  # ed.cell_mesh = StaticBoxMesh(zero(Vec3f), Vec3f(dims[1], dims[2], dims[3]/2f0))
  ed.cell_mesh = StaticBoxMesh(p0, p1)

  println(p0)
  println(p1)
  println(p)

  println(p1 - p0)
  println(p - p1)

  nothing
end

update!(ed::Editor) = begin
  if ed.frame % 60 == 0
    for view = ed.views
      reload!(view.shader)
    end
  end
  ed.frame += 1

  # check_bgtask(ed)

  for view = ed.views
    update!(view)
  end
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
  CImGui.Text("Camera position: $(ed.views[1].camera.pose.p)")
  CImGui.End()

  for view = ed.views
    draw!(view)
  end
  glBindFramebuffer(GL_FRAMEBUFFER, 0)
  nothing
end


# Commands #####################################################################

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
