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

camera_ray_dir(ndc::Vec2f, proj_mat::Mat4f, view_mat::Mat4f) = begin
  # Convert to homogeneous clip coordinates
  ray_clip = Vec4f(ndc[1], ndc[2], -1f0, 1f0)
  # Convert to eye (camera) coordinates
  ray_eye = inv(proj_mat) * ray_clip
  ray_eye = Vec4f(ray_eye[1], ray_eye[2], -1.0, 0.0)
  # Convert to world coordinates
  normalize(inv(view_mat) * ray_eye)
end

