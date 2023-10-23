
mutable struct View
  name :: String
  fb :: Framebuffer
  shader :: Shader
  camera :: Camera
  wireframe :: Bool
end

View(name::String) =
  View(
    name,
    Framebuffer(),
    Shader("shader.glsl"),
    PerspectiveCamera(Vec3f(2f0, 2f0, 3f0), zero(Vec3f), Vec3f(0,0,1), 1f0),
    false,
  )

update!(view::View) = begin
  if CImGui.IsKeyPressed(GLFW_KEY_W)
    view.wireframe = !view.wireframe
  end
end

draw!(view::View) = begin
  CImGui.Begin(view.name, C_NULL, ImGuiWindowFlags_NoScrollbar)
  view_size = CImGui.GetContentRegionAvail()
  width, height = floor(Int, view_size.x), floor(Int, view_size.y)
  if width > 0 && height > 0
    resize!(view.fb, width, height)
    view.camera.aspect = width/height

    glBindFramebuffer(GL_FRAMEBUFFER, view.fb.id)
    glEnable(GL_DEPTH_TEST)
    glViewport(0, 0, width, height)
    glClearColor(1.0, 1.0, 1.0, 1.0)
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT)
    glPolygonMode(GL_FRONT_AND_BACK, if view.wireframe GL_LINE else GL_FILL end)
    set_uniforms(view.camera, view.shader)
    set_textures(the_scene.scanvol, view.shader)
    set_uniforms(the_scene.scanvol, view.shader)

    for object = the_scene.objects
      draw!(object)
    end

    glBindFramebuffer(GL_FRAMEBUFFER, 0)
    CImGui.Image(Ptr{Cvoid}(UInt(view.fb.texid)), view_size)
  end
  CImGui.End()
end

toggle_view_wireframe!() = begin
  view = view_under_mouse()
  view.wireframe = !view.wireframe
end
