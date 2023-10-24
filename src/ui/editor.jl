struct EditorMode
  name::String
end

const MODE_NORMAL = EditorMode("normal")

Base.@kwdef mutable struct Editor
  mode :: EditorMode = MODE_NORMAL
  frame :: Int = 0
  views :: Vector{View} = View[]

  vol = nothing
end

load_scene_scan_volume!() = begin
  load_small!(the_scene.scanvol) # This should happen on a bg thread.
  println("Loading scan volume into GPU...")
  load_textures(the_scene.scanvol) # This should happen after, on the main thead.
  println("Loaded into GPU.")
end

init!(ed::Editor) = begin
  push!(ed.views, View("3D View", the_scene.camera))
  # push!(ed.views, View("Front View", the_scene.camera)) # TODO: camera
  # push!(ed.views, View("Cross View", the_scene.camera)) # TODO: camera
end

struct KeyBinding
  key::Int32
  mods::Int32
end

const KeyMap = Dict{KeyBinding, Function}

KEYMAP_NORMAL = KeyMap(
  KeyBinding(GLFW_KEY_SPACE, 0) => toggle_view_wireframe!,
  KeyBinding(GLFW_KEY_L, 0) => load_scene_scan_volume!,
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

update!(ed::Editor) = begin
  if ed.frame % 60 == 0
    for view = ed.views
      reload!(view.shader)
    end
  end
  ed.frame += 1

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
  CImGui.Text("Camera position: $(ed.views[1].camera.pose.p)")
  CImGui.Text("Camera quaternion:  $(ed.views[1].camera.pose.q)")
  CImGui.Text("Camera viewmatrix:")
  vm = view_matrix(ed.views[1].camera.pose)
  for i = 1:4
    CImGui.Text("  $(vm[i,:])")
  end
  CImGui.End()

  for view = ed.views
    draw!(view)
  end
  glBindFramebuffer(GL_FRAMEBUFFER, 0)
  nothing
end

