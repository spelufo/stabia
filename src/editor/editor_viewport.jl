# Init #########################################################################

reset_views!(ed::Editor) = begin
  p = ed.cell.p
  c = center(ed.cell)
  L = ed.cell.L

  name = "3D View"
  ed.view_3d = Viewport(name, PerspectiveCamera(p + 1.5f0*L*Vec3f(1, 1, 0.9), p, Ez, 1))

  name = "Top View"
  n = 2f0 * L * Ez
  ed.view_top = Viewport(name, OrthographicCamera(c + n, -n, Ey, L, L))

  name = "Cross View"
  n = 2f0 * L * Ey
  ed.view_cross = Viewport(name, OrthographicCamera(c + n, -n, Ez, L, L))
end


# View 3d ######################################################################

do_view_3d(ed::Editor, view::Viewport) = begin
  BeginViewport(ed, view)

  draw_perps(ed, view)
  do_perps_add(ed, view)
  do_axis_planes(ed, view.shader)
  draw_brush_traces(ed, view, ed.brush)
  # !isnothing(ed.sim.sheet) && draw(ed.sim.sheet, view.shader)
  # !isnothing(ed.cell.holes) && ed.draw_holes[] && do_holes(ed.cell, view.shader)

  EndViewport(ed, view)
end


# View Top #####################################################################

do_view_top(ed::Editor, view::Viewport) = begin
  BeginViewport(ed, view)

  draw_perps(ed, view)
  do_perps_add(ed, view)
  do_axis_planes(ed, view.shader)
  # !isnothing(ed.sheet) && draw(ed.sheet, view.shader)

  EndViewport(ed, view)
end


# View Cross ###################################################################

do_view_cross(ed::Editor, view::Viewport) = begin
  BeginViewport(ed, view)
  draw_perps_cross_view(ed, view)
  if ed.perps.state == :stable
    ed.brush.state = :editing
  else
    ed.brush.state = :stable
  end
  do_brush(ed, view, ed.brush)
  draw_brush_traces(ed, view, ed.brush)

  EndViewport(ed, view)
end


# Common #######################################################################


screen_to_ndc(view::Viewport, p::ImVec2) =
  Vec2f(2f0 * p.x / view.size.x - 1f0, 1f0 - 2f0 * p.y / view.size.y)

mouse_ray(view::Viewport, mpos) =
  camera_ray(view.camera, screen_to_ndc(view, mpos))

BeginViewport(ed::Editor, view::Viewport) = begin
  CImGui.Begin(view.name)
  view.size = CImGui.GetContentRegionAvail()
  width = floor(Int, view.size.x)
  height = floor(Int, view.size.y)
  view.visible = width > 0 && height > 0
  if view.visible
    resize_fb!(view.fb, width, height)
    set_viewport!(view.camera, width, height)

    glBindFramebuffer(GL_FRAMEBUFFER, view.fb.id)
    glEnable(GL_DEPTH_TEST)
    glViewport(0, 0, width, height)
    glPolygonMode(GL_FRONT_AND_BACK, if view.wireframe GL_LINE else GL_FILL end)

    glClearColor(0.5, 0.5, 0.5, 1.0)
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT)

    glUniform1i(glGetUniformLocation(view.shader, "style"), ed.style)
    set_uniforms(view.camera, view.shader)
    set_uniforms(ed.cell, view.shader)
    set_textures(ed.cell, view.shader)
  end
  view.pos = CImGui.GetWindowPos() + CImGui.GetCursorPos()
end

EndViewport(ed::Editor, view::Viewport) = begin
  glBindFramebuffer(GL_FRAMEBUFFER, 0)
  if view.visible
    CImGui.Image(Ptr{Cvoid}(UInt(view.fb.texid)), view.size, ImVec2(0, 1), ImVec2(1, 0))
  end
  CImGui.End()
end

