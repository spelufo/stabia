struct EditorMode
  name::String
end

const MODE_NORMAL = EditorMode("normal")

Base.@kwdef mutable struct Editor
  mode :: EditorMode = MODE_NORMAL
  frame :: Int = 0
  cell :: Tuple{Int, Int, Int} = (7, 7, 14)
  views :: Vector{View} = View[]
end

init!(ed::Editor) = begin
  push!(ed.views, View("3D View", 880, 992))
  # push!(ed.views, View("Front View", 854, 494))
  # push!(ed.views, View("Cross View", 854, 496))
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
  LibCImGui.igDockSpaceOverViewport(C_NULL, 0, C_NULL)

  CImGui.Begin("Toolbar")
  CImGui.Text("Toolbaroo!")
  CImGui.End()

  CImGui.Begin("Property Panel")
  CImGui.Text("Properly!")
  CImGui.End()

  CImGui.Begin("Main Content Area")
  CImGui.Text("Content creation!")
  CImGui.End()

  # for view = ed.views
  #   draw!(view)
  # end
  glBindFramebuffer(GL_FRAMEBUFFER, 0)
  nothing
end

