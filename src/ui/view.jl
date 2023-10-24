
mutable struct View
  name :: String
  fb :: Framebuffer
  shader :: Shader
  camera :: Camera
  wireframe :: Bool
end

View(name::String, camera::Camera) =
  View(
    name,
    Framebuffer(),
    Shader("shader.glsl"),
    camera,
    false,
  )

draw_on_view!(draw_fn::Function, view::View) = begin
  CImGui.Begin(view.name, C_NULL, ImGuiWindowFlags_NoScrollbar)
  if CImGui.IsKeyPressed(GLFW_KEY_W)
    view.wireframe = !view.wireframe
  end
  view_size = CImGui.GetContentRegionAvail()
  width, height = floor(Int, view_size.x), floor(Int, view_size.y)
  if width > 0 && height > 0
    if resize!(view.fb, width, height)
      # println("Resized view framebuffer: $width × $height")
    end
    set_viewport!(view.camera, width, height)

    glBindFramebuffer(GL_FRAMEBUFFER, view.fb.id)
    glEnable(GL_DEPTH_TEST)
    glViewport(0, 0, width, height)
    glPolygonMode(GL_FRONT_AND_BACK, if view.wireframe GL_LINE else GL_FILL end)

    glClearColor(1.0, 1.0, 1.0, 1.0)
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT)

    set_uniforms(view.camera, view.shader)
    set_uniforms(the_scene.scanvol, view.shader)
    set_textures(the_scene.scanvol, view.shader)

    draw_fn(view.shader, width, height)

    glBindFramebuffer(GL_FRAMEBUFFER, 0)
    CImGui.Image(Ptr{Cvoid}(UInt(view.fb.texid)), view_size, ImVec2(0, 1), ImVec2(1, 0))
  end
  CImGui.End()
end
