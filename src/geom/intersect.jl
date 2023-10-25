
mutable struct Plane
  p :: Vec3f
  n :: Vec3f
end


mutable struct Ray
  p :: Vec3f
  v :: Vec3f
end


@inline intersect(r::Ray, s::Plane) = begin
  λ = (dot(s.p, s.n) - dot(s.n, r.p)) / dot(s.n, r.v)
  r.p + λ*r.v
end
