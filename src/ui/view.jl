
mutable struct View
  name :: String
  fb :: Framebuffer
  shader :: Shader
  camera :: Camera
  wireframe :: Bool
end

View(name::String, width::Int, height::Int) =
  View(
    name,
    Framebuffer(width, height),
    Shader("shader.glsl"),
    PerspectiveCamera(Vec3f(2f0, 2f0, 3f0), zero(Vec3f), Vec3f(0,0,1), width/height),
    true,
  )

update!(view::View) = begin
  # view.wireframe = CImGui.IsMouseHoveringWindow()
end

draw!(view::View) = begin
  CImGui.Begin(view.name, C_NULL, ImGuiWindowFlags_NoScrollbar)
  size = CImGui.GetContentRegionAvail() # This looks like it's not the right thing.
  width, height = floor(Int, size.x), floor(Int, size.y)
  resize!(view.fb, width, height)
  view.camera.aspect = width/height

  glBindFramebuffer(GL_FRAMEBUFFER, view.fb.id)
  glClearColor(1.0, 1.0, 1.0, 1.0)
  glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT)

  if view.wireframe
    glPolygonMode(GL_FRONT_AND_BACK, GL_LINE)
  else
    glPolygonMode(GL_FRONT_AND_BACK, GL_FILL)
  end

  set_uniforms(view.camera, view.shader)
  for object = the_scene.objects
    draw!(object)
  end

  glBindFramebuffer(GL_FRAMEBUFFER, 0)
  CImGui.Image(Ptr{Cvoid}(UInt(view.fb.texid)), size)
  CImGui.End()
end


toggle_view_wireframe!() = begin
  view = view_under_mouse()
  view.wireframe = !view.wireframe
end
