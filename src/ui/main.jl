using GLFW, ModernGL

include("render/shaders.jl")
include("editor.jl")

@defonce the_window = nothing
@defonce the_editor = nothing

on_frame() = begin
  glClearColor(1f0, 0f0, 1f0, 1f0)
  glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT)
  update!(the_editor)
  draw!(the_editor)
end

on_key(window::GLFW.Window, key::GLFW.Key, scancode::Int32, action::GLFW.Action, mode::Int32) = begin
  if key == GLFW.KEY_ESCAPE
    GLFW.SetWindowShouldClose(window, true)
  end
end

on_mouse(window::GLFW.Window, button::GLFW.MouseButton, action::GLFW.Action, mode::Int32) =
  nothing


create_window() = begin
  GLFW.WindowHint(GLFW.CLIENT_API, GLFW.OPENGL_API)
  GLFW.WindowHint(GLFW.OPENGL_PROFILE, GLFW.OPENGL_CORE_PROFILE)
  GLFW.WindowHint(GLFW.CONTEXT_VERSION_MAJOR, 4)
  GLFW.WindowHint(GLFW.CONTEXT_VERSION_MINOR, 2)
  GLFW.WindowHint(GLFW.OPENGL_DEBUG_CONTEXT, true)
  GLFW.WindowHint(GLFW.VISIBLE, false)
  window = GLFW.CreateWindow(800, 600, "Stabia")

  GLFW.SetWindowPos(window, 100, 100)
  GLFW.ShowWindow(window)

  GLFW.SetKeyCallback(window, (window::GLFW.Window, key::GLFW.Key, scancode::Int32, action::GLFW.Action, mode::Int32) -> Base.invokelatest(on_key, window, key, scancode, action, mode))
  GLFW.SetMouseButtonCallback(window, (window::GLFW.Window, button::GLFW.MouseButton, action::GLFW.Action, mode::Int32) -> Base.invokelatest(on_mouse, window, button, action, mode))
  # GLFW.SetFramebufferSizeCallback(window, (window::GLFW.Window, width::Int32, height::Int32) -> Base.invokelatest(on_framebuffer_size, window, width, height))
  # GLFW.SetWindowSizeCallback(window, (window::GLFW.Window, width::Int32, height::Int32) -> Base.invokelatest(on_window_size, window, width, height))

  GLFW.MakeContextCurrent(window)
  GLFW.SwapInterval(1)

  window
end

main() = begin
  global the_window;  the_window = create_window()
  global the_editor;  the_editor = Editor()
  while !GLFW.WindowShouldClose(the_window)
    yield()  # Allow other tasks to run (e.g. the repl).
    Base.invokelatest(on_frame)
    GLFW.SwapBuffers(the_window)
    GLFW.PollEvents()
  end
  GLFW.DestroyWindow(the_window)
  the_window = nothing
end

# Start main from the julia repl, like this:
# schedule(Task(main))
