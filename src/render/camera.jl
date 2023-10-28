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

position(cam::PerspectiveCamera) =
  cam.pose.p

camera_view_matrix(cam::PerspectiveCamera) =
  view_matrix(cam.pose)

camera_proj_matrix(cam::PerspectiveCamera) =
  perspective(cam.fov, cam.aspect, cam.near, cam.far)

camera_ray(cam::PerspectiveCamera, ndc::Vec2f) = begin
  view = camera_view_matrix(cam)
  proj = camera_proj_matrix(cam)
  ray_clip = Vec4f(ndc[1], ndc[2], -1f0, 1f0)
  ray_eye = inv(proj) * ray_clip
  ray_eye = Vec4f(ray_eye[1], ray_eye[2], -1.0, 0.0)
  ray_dir = normalize(inv(view) * ray_eye)
  Ray(position(cam), ray_dir)
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

position(cam::OrthographicCamera) =
  cam.p

camera_view_matrix(cam::OrthographicCamera) =
  lookat(cam.p, cam.p + cam.n, cam.up)

camera_proj_matrix(cam::OrthographicCamera) =
  ortho(-cam.w/2, cam.w/2, -cam.h/2, cam.h/2, 0f0, cam.z)

camera_ray(cam::OrthographicCamera, ndc::Vec2f) = begin
  view_mat = camera_view_matrix(cam)
  half_width = cam.w / 2.0
  half_height = cam.h / 2.0
  world_pos_x = ndc[1] * half_width
  world_pos_y = ndc[2] * half_height
  world_pos = inv(view_mat) * Vec4f(world_pos_x, world_pos_y, -cam.z, 1.0)
  ray_dir = -normalize(cam.n)
  Ray(Vec3f(world_pos[1], world_pos[2], world_pos[3]), ray_dir)
end

# Common #######################################################################

set_uniforms(cam::Camera, shader::Shader) = begin
  p = position(cam)
  glUniform3f(glGetUniformLocation(shader, "cam"), p[1], p[2], p[3])
  glUniformMatrix4fv(glGetUniformLocation(shader, "view"), 1, GL_FALSE, camera_view_matrix(cam))
  glUniformMatrix4fv(glGetUniformLocation(shader, "proj"), 1, GL_FALSE, camera_proj_matrix(cam))
end
