
# Quaternion ###################################################################

Quaternions.quat(s::F, v::Vec3{F}) where F<:AbstractFloat =
  quat(s, v[1], v[2], v[3])

Quaternions.quat(v::Vec3{F})  where F<:AbstractFloat =
  quat(zero(F), v)

vector_part(q::Quaternion{F}) where F<:AbstractFloat =
  Vec3{F}(q.v1, q.v2, q.v3)

"The quaternion that rotates around axis by angle."
rotation_quat(axis::Vec3{F}, angle::F) where F<:AbstractFloat =
  quat(cos(angle/2), sin(angle/2)*normalize(axis))

"The quaternion that rotates a to b through the plane they determine."
rotation_quat(a::Vec3{F}, b::Vec3{F}) where F<:AbstractFloat = begin
  a = normalize(a); b = normalize(b)
  axis = cross(a, b)
  if norm(axis) ≈ 0f0
    quat(1f0)
  else
    rotation_quat(axis, angle(a, b))
  end
end

"The quaternion that rotates around axis from a to b."
rotation_quat(axis::Vec3{F}, a::Vec3{F}, b::Vec3{F}) where F<:AbstractFloat = begin
  a = normalize(a); b = normalize(b)
  rotation_quat(a - project(a, axis), b - project(b, axis))
end

"Rotate v by a quaternion."
rotate(v::Vec3{F}, by::Quaternion{F}) where F<:AbstractFloat =
  vector_part(by*quat(v)*conj(by))

"Rotate q by a quaternion."
rotate(q::Quaternion{F}, by::Quaternion{F}) where F<:AbstractFloat =
  by*q

"Rotate x around axis by angle."
rotate(x, axis::Vec3{F}, angle::F) where F<:AbstractFloat =
  rotate(x, rotation_quat(axis, angle))

"Rotation matrix that does the same rotation as q."
rotation_matrix(q::Quaternion{F}) where F<:AbstractFloat = begin
  rx = rotate(Vec3{F}(1.0, 0.0, 0.0), q)
  ry = rotate(Vec3{F}(0.0, 1.0, 0.0), q)
  rz = rotate(Vec3{F}(0.0, 0.0, 1.0), q)
  @SMatrix F[
    rx[1] ry[1] rz[1] 0.0;
    rx[2] ry[2] rz[2] 0.0;
    rx[3] ry[3] rz[3] 0.0;
    0.0   0.0   0.0   1.0;
  ]
end

# Older, buggy for some cases.
# lookat_quat(p::Vec3{F}, target::Vec3{F}, up::Vec3{F}) where F<:AbstractFloat = begin
#   m = lookat(p, target, up)[1:3,1:3]
#   e = eigen(m)
#   for i in 1:3
#     if isreal(e.values[i])
#       return rotation_quat(Vec3f(e.vectors[:, i]), acos((tr(m)-1f0)/2f0))
#     end
#   end
#   @assert false "unreachable"
# end

lookat_quat(p::Vec3{F}, target::Vec3{F}, up::Vec3{F}) where F<:AbstractFloat = begin
  dir = normalize(target - p)
  # Rotates -Ez to dir.
  q1 = rotation_quat(-Ez, dir)
  # Rotates the new Ey to up through axis dir.
  q2 = rotation_quat(dir, rotate(Ey, q1), up)
  q2*q1
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
  rotate(p, pose.q) + pose.p

world_to_pose(pose::Pose{F}, p::Vec3{F}) where F<:AbstractFloat =
  rotate(p - pose.p, conj(pose.q))

pose_vec_to_world_vec(pose::Pose{F}, p::Vec3{F}) where F<:AbstractFloat =
  rotate(p, pose.q)

world_vec_to_pose_vec(pose::Pose{F}, p::Vec3{F}) where F<:AbstractFloat =
  rotate(p, conj(pose.q))

move(pose::Pose{F}, v::Vec3f) where F<:AbstractFloat =
  Pose(pose.p + v, pose.q)

xdir(pose::Pose{F}) where F<:AbstractFloat =
  pose_vec_to_world_vec(pose, Vec3{F}(1.0, 0.0, 0.0))

ydir(pose::Pose{F}) where F<:AbstractFloat =
  pose_vec_to_world_vec(pose, Vec3{F}(0.0, 1.0, 0.0))

zdir(pose::Pose{F}) where F<:AbstractFloat =
  pose_vec_to_world_vec(pose, Vec3{F}(0.0, 0.0, 1.0))

frame(pose::Pose{F}) where F<:AbstractFloat =
  rotation_matrix(pose.q)

rotate(pose::Pose{F}, by::Quaternion{F}) where F<:AbstractFloat =
  Pose(pose.p, rotate(pose.q, by))

orientation_matrix(pose::Pose{F}) where F<:AbstractFloat =
  rotation_matrix(conj(pose.q))

view_matrix(pose::Pose{F}) where F<:AbstractFloat =
  orientation_matrix(pose)*translation(-pose.p)

lookat_pose(p::Vec3{F}, target::Vec3{F}, up::Vec3{F}) where F<:AbstractFloat =
  Pose(p, lookat_quat(p, target, up))

model_matrix(pose::Pose{F}) where F<:AbstractFloat =
  orientation_matrix(pose)*translation(pose.p)
