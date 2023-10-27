abstract type Camera end


# Perspective ##################################################################

mutable struct PerspectiveCamera <: Camera
  pose :: Pose{Float32}
  aspect :: Float32
  fov :: Float32
  near :: Float32
  far :: Float32

  # TODO: Separate this struct into a static data part with the fields above
  # and a mutable wrapping camera object with the additional fields below.
  # speed :: Float32
  # sensitivity :: Float32
  # last_mouse_p :: Vec2f
  # mouse_control :: Bool
end

CAMERA_SPEED = 100.0f0
CAMERA_SENSITIVITY = 0.05f0

PerspectiveCamera(p, target, up, aspect) = begin
  pose = lookat_pose(p, target, up)
  PerspectiveCamera(pose, aspect, 45*pi/180, 0.001f0, 10000f0)
    # CAMERA_SPEED, CAMERA_SENSITIVITY, mouse_position(ed.window), false)
end

set_viewport!(camera::PerspectiveCamera, width, height) = begin
  camera.aspect = width/height
  nothing
end

set_uniforms(cam::PerspectiveCamera, shader::Shader) = begin
  view = view_matrix(cam.pose)
  proj = perspective(cam.fov, cam.aspect, cam.near, cam.far)
  p = cam.pose.p
  glUniform3f(glGetUniformLocation(shader, "cam"), p[1], p[2], p[3])
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

set_viewport!(camera::OrthographicCamera, width, height) = begin
  aspect = width/height
  camera.w = 3.95f0 * aspect
  camera.h = 3.95f0
  nothing
end

set_uniforms(cam::OrthographicCamera, shader::Shader) = begin
  view = lookat(cam.p, cam.p + cam.n, cam.up)
  proj = ortho(-cam.w/2, cam.w/2, -cam.h/2, cam.h/2, 0f0, cam.z)
  glUniform3f(glGetUniformLocation(shader, "cam"), cam.p[1], cam.p[2], cam.p[3])
  glUniformMatrix4fv(glGetUniformLocation(shader, "view"), 1, GL_FALSE, view)
  glUniformMatrix4fv(glGetUniformLocation(shader, "proj"), 1, GL_FALSE, proj)
end
