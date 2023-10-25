const E0 = Vec3f(0f0, 0f0, 0f0)
const E1 = Vec3f(1f0, 1f0, 1f0)
const Ex = Vec3f(1f0, 0f0, 0f0)
const Ey = Vec3f(0f0, 1f0, 0f0)
const Ez = Vec3f(0f0, 0f0, 1f0)

snap_to_axis(v::Vec3{F}) where F<:AbstractFloat = begin
  k = argmax(abs.(reverse(v)))
  Vec3{F}([i==k ? sign(v[i]) : zero(F) for i in 1:3])
end
