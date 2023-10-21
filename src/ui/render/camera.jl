abstract type Camera end


# Perspective ##################################################################

mutable struct PerspectiveCamera <: Camera
  pose :: Pose{Float32}
  aspect :: Float32
  fov :: Float32
  near :: Float32
  far :: Float32
  speed :: Float32
  sensitivity :: Float32
  last_mouse_p :: Vec2f
  mouse_control :: Bool
end

CAMERA_SPEED = 100.0f0
CAMERA_SENSITIVITY = 0.05f0

PerspectiveCamera(p, target, up, aspect) = begin
  q = lookat_quat(p, target, up)
  PerspectiveCamera(Pose(p, q), aspect, 45*pi/180, 0.1f0, 1000f0,
    CAMERA_SPEED, CAMERA_SENSITIVITY, mouse_position(ed.window), false)
end

set_uniforms(cam::PerspectiveCamera, shader::Shader) = begin
  view = view_matrix(cam.pose)
  proj = perspective(cam.fov, cam.aspect, cam.near, cam.far)
  p = cam.pose.p
  glUniform3f(glGetUniformLocation(shader, "cam"), p.x, p.y, p.z)
  glUniformMatrix4fv(glGetUniformLocation(shader, "view"), 1, GL_FALSE, view)
  glUniformMatrix4fv(glGetUniformLocation(shader, "proj"), 1, GL_FALSE, proj)
end

move!(cam::PerspectiveCamera, dir::Vec3f, dt::Float32) =
  cam.pose = Pose{Float32}(
    cam.pose.p + cam.speed * dt * pose_vec_to_world_vec(cam.pose, dir),
    cam.pose.q,
  )

rotate!(cam::PerspectiveCamera, axis::Vec3f, angle::Float32, dt::Float32) =
  cam.pose = Pose{Float32}(
    cam.pose.p,
    cam.pose.q * rotation_quat(axis, cam.sensitivity * dt * angle),
  )

update(cam::PerspectiveCamera, dt::Float32) = begin
  cam.aspect = ed.layout.window_width / ed.layout.window_height
  if is_down(ed.keyboard, GLFW.KEY_1)  cam.speed = CAMERA_SPEED  end
  if is_down(ed.keyboard, GLFW.KEY_2)  cam.speed = CAMERA_SPEED/2  end
  if is_down(ed.keyboard, GLFW.KEY_3)  cam.speed = CAMERA_SPEED/4  end
  if is_down(ed.keyboard, GLFW.KEY_4)  cam.speed = CAMERA_SPEED/8  end
  if is_down(ed.keyboard, GLFW.KEY_5)  cam.speed = CAMERA_SPEED/16  end
  if is_down(ed.keyboard, GLFW.KEY_W)  move!(cam, -vec3f_z, dt)  end
  if is_down(ed.keyboard, GLFW.KEY_S)  move!(cam, vec3f_z, dt)  end
  if is_down(ed.keyboard, GLFW.KEY_D)  move!(cam, vec3f_x, dt)  end
  if is_down(ed.keyboard, GLFW.KEY_A)  move!(cam, -vec3f_x, dt)  end
  if is_down(ed.keyboard, GLFW.KEY_E)  move!(cam, vec3f_y, dt)  end
  if is_down(ed.keyboard, GLFW.KEY_Q)  move!(cam, -vec3f_y, dt)  end

  # TODO: Orbit instead of FPS.
  mouse_p = mouse_position(ed.window)
  if was_released(ed.keyboard, GLFW.KEY_SPACE)
    cam.mouse_control = !cam.mouse_control
    if cam.mouse_control
      GLFW.SetInputMode(ed.window, GLFW.CURSOR, GLFW.CURSOR_DISABLED)
    else
      GLFW.SetInputMode(ed.window, GLFW.CURSOR, GLFW.CURSOR_NORMAL)
    end
  end
  if cam.mouse_control
    v_up = world_vec_to_pose_vec(cam.pose, vec3f_z)
    mouse_v = mouse_p - cam.last_mouse_p
    yaw = -mouse_v[1]
    pitch = mouse_v[2]
    rotate!(cam, v_up, yaw, dt)
    rotate!(cam, vec3f_x, pitch, dt)
  end
  cam.last_mouse_p = mouse_p
end

# Orthographic #################################################################

mutable struct OrthographicCamera <: Camera
  p :: Vec3f
  n :: Vec3f
  up :: Vec3f
  w :: Float32
  h :: Float32
  z :: Float32
end

OrthographicCamera(p, n, up, w, h) =
  OrthographicCamera(p, n, up, w, h, 1000f0)

set_uniforms(cam::OrthographicCamera, shader::Shader) = begin
  view = lookat(cam.p, cam.p + cam.n, cam.up)
  proj = ortho(-cam.w/2, cam.w/2, -cam.h/2, cam.h/2, 0f0, cam.z)
  glUniform3f(glGetUniformLocation(shader, "cam"), cam.p.x, cam.p.y, cam.p.z)
  glUniformMatrix4fv(glGetUniformLocation(shader, "view"), 1, GL_FALSE, view)
  glUniformMatrix4fv(glGetUniformLocation(shader, "proj"), 1, GL_FALSE, proj)
end

# OrthographicCamera(dims.*Vec3f(0.5, 0.5, 1.0), -vec3f_z, vec3f_y, dims.x, dims.y)
# OrthographicCamera(dims.*Vec3f(1.0, 0.5, 0.5), -vec3f_x, vec3f_z, dims.y, dims.z)
# OrthographicCamera(dims.*Vec3f(0.5, 1.0, 0.5), -vec3f_y, vec3f_x, dims.z, dims.x)





















# mutable struct PerspectiveCamera <: Camera
#   p :: Vec3f
#   front :: Vec3f
#   up :: Vec3f
#   aspect :: Float32
#   fov :: Float32
#   near :: Float32
#   far :: Float32
#   speed :: Float64
# end

# PerspectiveCamera(p, target, up, aspect) =
#   PerspectiveCamera(p, normalize(target - p), normalize(up), aspect, 45*pi/180, 0.1f0, 1000f0, 10.0)

# set_uniforms(cam::PerspectiveCamera, shader::Shader) = begin
#   x = normalize(cross(cam.up, cam.front))
#   @assert norm(x) ≈ 1f0 "colinear cam.up and cam.p-cam.target"
#   view = lookat(cam.p, cam.p + cam.front, cam.up)
#   proj = perspective(cam.fov, cam.aspect, cam.near, cam.far)
#   glUniform3f(glGetUniformLocation(shader, "cam"), cam.p.x, cam.p.y, cam.p.z)
#   glUniformMatrix4fv(glGetUniformLocation(shader, "view"), 1, GL_FALSE, view)
#   glUniformMatrix4fv(glGetUniformLocation(shader, "proj"), 1, GL_FALSE, proj)
# end

# move_forward!(cam::PerspectiveCamera, dt::Float64) =
#   cam.p += cam.speed * dt * cam.front

# move_backward!(cam::PerspectiveCamera, dt::Float64) =
#   cam.p -= cam.speed * dt * cam.front

# move_right!(cam::PerspectiveCamera, dt::Float64) = begin
#   right = cross(cam.front, cam.up)
#   cam.p += cam.speed * dt * right
# end

# move_left!(cam::PerspectiveCamera, dt::Float64) = begin
#   right = cross(cam.front, cam.up)
#   cam.p -= cam.speed * dt * right
# end

# move_up!(cam::PerspectiveCamera, dt::Float64) =
#   cam.p += cam.speed * dt * cam.up

# move_down!(cam::PerspectiveCamera, dt::Float64) =
#   cam.p -= cam.speed * dt * cam.up

