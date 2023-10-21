
mutable struct View
  x0 :: Int32; y0 :: Int32; x1 :: Int32; y1 :: Int32

  View() = new(0, 0, 0, 0)
end

mutable struct Editor
  views :: Vector{View}
  shader :: Shader
  frame :: Int

  Editor() =
    new(
      [View(), View(), View(), View()],
      Shader("shader.glsl"),
      0,
    )
end


update!(ed::Editor) = begin
  if ed.frame % 60 == 0  reload!(ed.shader)  end
  for view in ed.views  update!(view)  end
  ed.frame += 1
end

update!(view::View) = begin
end

draw!(ed::Editor) = begin
  width, height = GLFW.GetFramebufferSize(the_window)
  ed.views[1].x0 = ed.views[2].x0 = 0
  ed.views[1].x1 = ed.views[2].x1 = ed.views[3].x0 = ed.views[4].x0 = width ÷ 2
  ed.views[3].x1 = ed.views[4].x1 = width
  ed.views[1].y0 = ed.views[3].y0 = 0
  ed.views[1].y1 = ed.views[3].y1 = ed.views[2].y0 = ed.views[4].y0 = height ÷ 2
  ed.views[2].y1 = ed.views[4].y1 = height
  for view in ed.views
    draw!(view)
  end
end

draw!(view::View) = begin
  glViewport(view.x0, view.y0, view.x1 - view.x0, view.y1 - view.y0)
end

# update(dt::Float64) = begin
#   update(ed.camera, Float32(dt))
#   vol = ed.vol
#   jy, jx, jz = vol.jy, vol.jx, vol.jz
#   if was_released(ed.keyboard, GLFW.KEY_I) move_focus!(vol, 0, 0,  1) end
#   if was_released(ed.keyboard, GLFW.KEY_K) move_focus!(vol, 0, 0, -1) end
#   if was_released(ed.keyboard, GLFW.KEY_L) move_focus!(vol,  1, 0, 0) end
#   if was_released(ed.keyboard, GLFW.KEY_J) move_focus!(vol, -1, 0, 0) end
#   if was_released(ed.keyboard, GLFW.KEY_O) move_focus!(vol, 0,  1, 0) end
#   if was_released(ed.keyboard, GLFW.KEY_U) move_focus!(vol, 0, -1, 0) end
#   if (jy, jx, jz) != (vol.jy, vol.jx, vol.jz)
#     ed.cellbounds = box_mesh(cell_position(vol)...)
#     load_textures(ed.vol)
#   end
# end

# set_uniforms() = begin
#   dims = dimensions(ed.vol)
#   glUniform1f(glGetUniformLocation(ed.shader, "time"), ed.t)
#   glUniform3f(glGetUniformLocation(ed.shader, "dimensions"), dims.x, dims.y, dims.z)
#   cutz = dims.z/3f0
#   glUniform4f(glGetUniformLocation(ed.shader, "clipplane"), 0f0, 0f0, 1f0, -cutz)
#   p0, p1 = cell_position(ed.vol)
#   glUniform3f(glGetUniformLocation(ed.shader, "cellp0"), p0.x, p0.y, p0.z)
#   glUniform3f(glGetUniformLocation(ed.shader, "cellp1"), p1.x, p1.y, p1.z)
# end

# draw_viewport() = begin
#   glViewport(get_viewport_area()...)
#   glUniform1i(glGetUniformLocation(ed.shader, "style"), 1)
#   set_uniforms(ed.camera, ed.shader)
#   draw(ed.bounds)
#   draw(ed.cellbounds)
# end

# draw_xy() = begin
#   glViewport(get_xy_area()...)
#   glUniform1i(glGetUniformLocation(ed.shader, "style"), 0)
#   # set_uniforms(ed.xy_camera, ed.shader)
#   draw(ed.bounds)
# end

# draw() = begin
#   glClearColor(0.05, 0.05, 0.05, 1.0)
#   glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT)
#   set_textures(ed.vol)
#   set_uniforms()
#   draw_viewport()
#   # draw_xy()
# end

# frame() = begin
#   if ed.frame % 60 == 0  update_shaders()  end
#   t = time() - ed.t0
#   dt = t - ed.t
#   ed.t = t
#   update(dt)
#   draw()
#   ed.frame += 1
#   handle_poll_events(ed.keyboard)
#   handle_poll_events(ed.mouse)
# end

# init_gl() = begin
#   glEnable(GL_DEPTH_TEST)
#   glEnable(GL_CLIP_DISTANCE0)
# end

# reset() = begin
#   ed.t0 = time()
#   ed.t = 0.0
#   glEnable(GL_CLIP_DISTANCE0)

#   dims = dimensions(ed.vol)
#   ed.bounds = box_mesh(Vec3f(0f0), dims)
#   ed.cellbounds = box_mesh(cell_position(ed.vol)...)
#   ed.camera = PerspectiveCamera(
#     1.25f0 * dims,
#     0.5f0 * dims,
#     vec3f_z,
#     1)

#   do_layout()
# end

# init(window, window_width, window_height) = begin
#   init_gl()
#   ed.window = window
#   ed.keyboard = Keyboard()
#   ed.mouse = Mouse()
#   ed.layout = EdLayout(window_width, window_height)
#   ed.shader = Shader("vis.glsl")
#   println("Loading scan volume...")
#   ed.vol = ScanVolume(scroll_1_54, 8, 8, 1)
#   println("Loaded to RAM.")
#   load_textures(ed.vol)
#   println("Loaded to GPU.")
#   reset()
#   nothing
# end
