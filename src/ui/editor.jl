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

init!(ed::Editor) = begin
  println("Loading scan volume into GPU...")
  load_textures(the_scene.scanvol)
  println("Loaded into GPU.")

  push!(ed.views, View("3D View"))
  push!(ed.views, View("Front View"))
  push!(ed.views, View("Cross View"))
end

struct KeyBinding
  key::Int32
  mods::Int32
end

const KeyMap = Dict{KeyBinding, Function}

KEYMAP_NORMAL = KeyMap(
  KeyBinding(GLFW_KEY_SPACE, 0) => toggle_view_wireframe!,
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
  CImGui.End()

  for view = ed.views
    draw!(view)
  end
  glBindFramebuffer(GL_FRAMEBUFFER, 0)
  nothing
end

