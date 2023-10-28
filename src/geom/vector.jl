const E0 = Vec3f(0f0, 0f0, 0f0)
const E1 = Vec3f(1f0, 1f0, 1f0)
const Ex = Vec3f(1f0, 0f0, 0f0)
const Ey = Vec3f(0f0, 1f0, 0f0)
const Ez = Vec3f(0f0, 0f0, 1f0)

snap_to_axis(v::Vec3{F}) where F<:AbstractFloat = begin
  k = argmax(abs.(reverse(v)))
  Vec3{F}([i==k ? sign(v[i]) : zero(F) for i in 1:3])
end

@inline angle(v::Vec3{F}, w::Vec3{F}) where F <: AbstractFloat = begin
  v = normalize(v)
  w = normalize(w)
  θ = acos(dot(v, w))
  if dot(v, cross(v, w)) < 0
    θ = -θ
  end
  θ
end

@inline project(a::Vec3{F}, axis::Vec3{F}) where F <: AbstractFloat =
  dot(a, axis)*normalize(axis)
