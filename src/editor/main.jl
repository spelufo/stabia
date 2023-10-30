using CImGui
using CImGui.LibCImGui
using CImGui.ImGuiGLFWBackend
using CImGui.ImGuiOpenGLBackend
using CImGui.ImGuiGLFWBackend.LibGLFW
using CImGui.ImGuiOpenGLBackend.ModernGL

include("utils.jl")
include("editor.jl")
include("editor_ui.jl")
include("viewport.jl")

@defonce the_doc = nothing
@defonce the_editor = nothing
@defonce the_window = nothing
@defonce the_window_width = Int32(1200)
@defonce the_window_height = Int32(800)
@defonce the_gpu_info = nothing

draw_frame() = begin
  begin # update window size
    win_width, win_height = Ref{Cint}(0), Ref{Cint}(0)
    glfwGetFramebufferSize(the_window, win_width, win_height)
    global the_window_width; the_window_width = win_width[]
    global the_window_height; the_window_height = win_height[]
    glViewport(0, 0, the_window_width, the_window_height)
  end
  begin # clear
    glClearColor(1f0, 1f0, 1f0, 1f0)
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT)
  end
  draw_frame(the_editor)
end

on_key(window::Ptr{GLFWwindow}, key::Cint, scancode::Cint, action::Cint, mods::Cint)::Cvoid = begin
  on_key!(the_editor, window, key, scancode, action, mods)
end

create_window() = begin
  glsl_version = 420
  glfwWindowHint(GLFW_CLIENT_API, GLFW_OPENGL_API)
  glfwWindowHint(GLFW_OPENGL_PROFILE, GLFW_OPENGL_CORE_PROFILE)
  glfwWindowHint(GLFW_CONTEXT_VERSION_MAJOR, 4)
  glfwWindowHint(GLFW_CONTEXT_VERSION_MINOR, 2)
  glfwWindowHint(GLFW_OPENGL_DEBUG_CONTEXT, true)
  glfwWindowHint(GLFW_VISIBLE, false)

  window = glfwCreateWindow(the_window_width, the_window_height, "Stabia", C_NULL, C_NULL)
  glfwSetWindowPos(window, 100, 100)
  glfwShowWindow(window)

  glfwSetKeyCallback(window, @cfunction(on_key, Cvoid, (Ptr{GLFWwindow}, Cint, Cint, Cint, Cint)))

  glfwMakeContextCurrent(window)
  glfwSwapInterval(1)

  ig_ctx = CImGui.CreateContext()
  ig_io = CImGui.GetIO()
  ig_io.ConfigFlags = unsafe_load(ig_io.ConfigFlags) | CImGui.ImGuiConfigFlags_DockingEnable
  # ig_io.IniFilename = C_NULL

  glfw_ctx = ImGuiGLFWBackend.create_context(window, install_callbacks=true)
  ImGuiGLFWBackend.init(glfw_ctx)
  gl_ctx = ImGuiOpenGLBackend.create_context(glsl_version)
  ImGuiOpenGLBackend.init(gl_ctx)

  window, ig_ctx, glfw_ctx, gl_ctx
end


main() = begin
  @assert isnothing(the_window) "Main window already open."
  println()

  global the_window
  the_window, ig_ctx, glfw_ctx, gl_ctx = create_window()
  println("Window created.")

  global the_doc
  if isnothing(the_doc)
    the_doc = Document(scroll_1_54, [Cell(scroll_1_54, (7,7,14))])
  end
  reload!(the_doc)
  println("Document initialized.")

  try
    global the_gpu_info
    the_gpu_info = GPUInfo()

    global the_editor
    the_editor = Editor(the_doc)
    println("Editor initialized.")

    while glfwWindowShouldClose(the_window) == GLFW_FALSE
      glfwPollEvents()
      yield()  # Allow other tasks to run (the repl).
      ImGuiOpenGLBackend.new_frame(gl_ctx)
      ImGuiGLFWBackend.new_frame(glfw_ctx)
      CImGui.NewFrame()
      Base.invokelatest(draw_frame)
      CImGui.Render()
      ImGuiOpenGLBackend.render(gl_ctx)
      glfwSwapBuffers(the_window)
    end
  finally
    global the_window
    ImGuiOpenGLBackend.shutdown(gl_ctx)
    ImGuiGLFWBackend.shutdown(glfw_ctx)
    CImGui.DestroyContext(ig_ctx)
    glfwDestroyWindow(the_window)
    the_window = nothing
  end
end

# To start asynchronously from the REPL. The usual dev workflow is:
# julia> include("src/stabia.jl"); start_stabia!()
# julia> include("src/stabia.jl") # reload code with the window still open
start_stabia!() =
  errormonitor(schedule(Task(main)))
