using LinearAlgebra, StaticArrays, GeometryBasics, Quaternions


# Vec ##########################################################################

# const vec3_x  = Vec3f(1.0, 0.0, 0.0)
# const vec3_y  = Vec3f(0.0, 1.0, 0.0)
# const vec3_z  = Vec3f(0.0, 0.0, 1.0)
# const vec3f_x = Vec3f(1f0, 0f0, 0f0)
# const vec3f_y = Vec3f(0f0, 1f0, 0f0)
# const vec3f_z = Vec3f(0f0, 0f0, 1f0)

snap_to_axis(v::Vec3{F}) where F<:AbstractFloat = begin
  k = argmax(abs.(reverse(v)))
  Vec3{F}([i==k ? sign(v[i]) : zero(F) for i in 1:3])
end

# Transformations ##############################################################

scaling(s::F) where F<:AbstractFloat =
  scaling(Vec3{F}(s, s, s))


scaling(s::Vec3{F}) where F<:AbstractFloat =
  @SMatrix F[
    s[1] 0.0 0.0 0.0;
    0.0 s[2] 0.0 0.0;
    0.0 0.0 s[3] 0.0;
    0.0 0.0 0.0 1.0;
  ]

scale(tr::Mat4{F}, s::F) where F<:AbstractFloat =
  scaling(s) * tr


translation(v::Vec3{F}) where F<:AbstractFloat =
  @SMatrix F[
    1.0 0.0 0.0 v[1];
    0.0 1.0 0.0 v[2];
    0.0 0.0 1.0 v[3];
    0.0 0.0 0.0 1.0;
  ]

translate(tr::Mat4{F}, v::Vec3{F}) where F<:AbstractFloat =
  translation(v) * tr

rotation(axis::Vec3{F}, angle::F) where F<:AbstractFloat = begin
  x = axis[1]; y = axis[2]; z = axis[3]; c = cos(angle); s = sin(angle)
  @SMatrix F[
    c + x*x*(1.0 - c)     x*y*(1.0 - c) - z*s   z*x*(1.0 - c) + y*s   0.0;
    x*y*(1.0 - c) + z*s   c + y*y*(1.0 - c)     y*z*(1.0 - c) - x*s   0.0;
    z*x*(1.0 - c) - y*s   y*z*(1.0 - c) + x*s   c + z*z*(1.0 - c)     0.0;
    0.0                   0.0                   0.0                   1.0;
  ]
end

rotate(tr::Mat4{F}, axis::Vec3{F}, angle::F) where F<:AbstractFloat =
  rotation(axis, angle) * tr

ortho(l::F, r::F, b::F, t::F, n::F, f::F) where F<:AbstractFloat =
  @SMatrix F[
    2.0/(r - l)   0.0           0.0           (-(r + l)/(r - l));
    0.0           2.0/(t - b)   0.0           (-(t + b)/(t - b));
    0.0           0.0          -2.0/(f - n)   (-(f + n)/(f - n));
    0.0           0.0           0.0           1.0;
  ]

perspective(l::F, r::F, b::F, t::F, n::F, f::F) where F<:AbstractFloat =
  @SMatrix F[
    2.0*n/(r - l)   0.0              (r + l)/(r - l)   0.0;
    0.0             2.0*n/(t - b)    (t + b)/(t - b)   0.0;
    0.0             0.0             -(f + n)/(f - n)   0.0;
    0.0             0.0             -1.0               0.0;
  ]

perspective(fovy::F, aspect::F, n::F, f::F) where F<:AbstractFloat =
  @SMatrix F[
    1.0/(aspect*tan(fovy/2.0))   0.0                  0.0                0.0;
    0.0                          1.0/tan(fovy/2.0)    0.0                0.0;
    0.0                          0.0                 -(f + n)/(f - n)   -2.0*f*n/(f - n);
    0.0                          0.0                 -1.0                0.0;
  ]

lookat(pos::Vec3{F}, target::Vec3{F}, up::Vec3{F}) where F<:AbstractFloat = begin
  z = normalize(pos - target)
  x = normalize(cross(up, z))
  y = cross(z, x)
  @SMatrix F[
    x[1]  x[2]  x[3]  -dot(x, pos);
    y[1]  y[2]  y[3]  -dot(y, pos);
    z[1]  z[2]  z[3]  -dot(z, pos);
    0.0   0.0   0.0    1.0;
  ]
end

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

pose_front(pose::Pose{F}) where F<:AbstractFloat =
  pose_vec_to_world_vec(pose, Vec3{F}(0.0, 0.0, -1.0))

pose_right(pose::Pose{F}) where F<:AbstractFloat =
  pose_vec_to_world_vec(pose, Vec3{F}(1.0, 0.0, 0.0))

pose_up(pose::Pose{F}) where F<:AbstractFloat =
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
