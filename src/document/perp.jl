
mutable struct Perp
  p :: Vec3f
  θ :: Float32 # relative to the x axis
end

Perp(p::Vec3f, p2::Vec3f) = begin
  v = normalize(Vec3f(p2[1], p2[2], p[3]) - p)
  Perp(p, angle(v, Ex))
end

perp_n(perp::Perp) =
  Vec3f(-sin(perp.θ), cos(perp.θ), 0f0)

perp_u(perp::Perp) =
  Vec3f(cos(perp.θ), sin(perp.θ), 0f0)

GLMesh(perp::Perp, p0::Vec3f, p1::Vec3f) = begin
  @assert all(p0 .<= perp.p .<= p1) "out of bounds: expected $p0 <= $(perp.p) <= $p1"
  a = Plane(p0,  Ex)
  b = Plane(p0,  Ey)
  c = Plane(p1, -Ex)
  d = Plane(p1, -Ey)
  r = Ray(perp.p,  perp_u(perp))
  pos_hit, pos_λ, neg_hit, neg_λ = raycast(r, Plane[a, b, c, d])

  GLQuadMesh(
    Vec3f(pos_hit[1], pos_hit[2], p0[3]),
    Vec3f(pos_hit[1], pos_hit[2], p1[3]),
    Vec3f(neg_hit[1], neg_hit[2], p1[3]),
    Vec3f(neg_hit[1], neg_hit[2], p0[3]),
  )
end
