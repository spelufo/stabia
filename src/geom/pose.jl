
# Quaternion ###################################################################

Quaternions.quat(s::F, v::Vec3{F}) where F<:AbstractFloat =
  quat(s, v[1], v[2], v[3])

Quaternions.quat(v::Vec3{F})  where F<:AbstractFloat =
  quat(zero(F), v)

vector_part(q::Quaternion{F}) where F<:AbstractFloat =
  Vec3{F}(q.v1, q.v2, q.v3)

rotation_quat(axis::Vec3{F}, angle::F) where F<:AbstractFloat =
  quat(cos(angle/2), sin(angle/2)*normalize(axis))

rotate(q::Quaternion{F}, v::Vec3{F}) where F<:AbstractFloat =
  vector_part(q*quat(v)*conj(q))

rotate(v::Vec3{F}, axis::Vec3{F}, angle::F) where F<:AbstractFloat =
  rotate(rotation_quat(axis, angle), v)

rotation_matrix(q::Quaternion{F}) where F<:AbstractFloat = begin
  rx = rotate(q, Vec3{F}(1.0, 0.0, 0.0))
  ry = rotate(q, Vec3{F}(0.0, 1.0, 0.0))
  rz = rotate(q, Vec3{F}(0.0, 0.0, 1.0))
  @SMatrix F[
    rx[1] ry[1] rz[1] 0.0;
    rx[2] ry[2] rz[2] 0.0;
    rx[3] ry[3] rz[3] 0.0;
    0.0   0.0   0.0   1.0;
  ]
end

lookat_quat(p::Vec3{F}, target::Vec3{F}, up::Vec3{F}) where F<:AbstractFloat = begin
  m = lookat(p, target, up)[1:3,1:3]
  e = eigen(m)
  for i in 1:3
    if isreal(e.values[i])
      return rotation_quat(Vec3f(e.vectors[:, i]), acos((tr(m)-1f0)/2f0))
    end
  end
  @assert false "unreachable"
end


# Pose #########################################################################

struct Pose{F<:AbstractFloat}
  p :: Vec3{F}
  q :: Quaternion{F}
end

Pose(p::Vec3{F}) where F<:AbstractFloat =
  Pose(p, one(Quaternion{F}))

Pose(q::Quaternion{F}) where F<:AbstractFloat =
  Pose(zero(Vec3{F}), q)

pose_to_world(pose::Pose{F}, p::Vec3{F}) where F<:AbstractFloat =
  rotate(pose.q, p) + pose.p

world_to_pose(pose::Pose{F}, p::Vec3{F}) where F<:AbstractFloat =
  rotate(conj(pose.q), p - pose.p)

pose_vec_to_world_vec(pose::Pose{F}, p::Vec3{F}) where F<:AbstractFloat =
  rotate(pose.q, p)

world_vec_to_pose_vec(pose::Pose{F}, p::Vec3{F}) where F<:AbstractFloat =
  rotate(conj(pose.q), p)

forward(pose::Pose{F}) where F<:AbstractFloat =
  pose_vec_to_world_vec(pose, Vec3{F}(0.0, 0.0, -1.0))

right(pose::Pose{F}) where F<:AbstractFloat =
  pose_vec_to_world_vec(pose, Vec3{F}(1.0, 0.0, 0.0))

up(pose::Pose{F}) where F<:AbstractFloat =
  pose_vec_to_world_vec(pose, Vec3{F}(0.0, 1.0, 0.0))

frame(pose::Pose{F}) where F<:AbstractFloat =
  rotation_matrix(pose.q)

orientation_matrix(pose::Pose{F}) where F<:AbstractFloat =
  rotation_matrix(conj(pose.q))

view_matrix(pose::Pose{F}) where F<:AbstractFloat =
  orientation_matrix(pose)*translation(-pose.p)

lookat_pose(p, target, up) =
  Pose(p, lookat_quat(p, target, up))

model_matrix(pose::Pose{F}) where F<:AbstractFloat =
  orientation_matrix(pose)*translation(pose.p)