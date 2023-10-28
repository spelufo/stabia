
struct Plane
  p :: Vec3f
  n :: Vec3f
end

struct Ray
  p :: Vec3f
  v :: Vec3f
end

@inline raycast(r::Ray, s::Plane) = begin
  λ = (dot(s.p, s.n) - dot(s.n, r.p)) / dot(s.n, r.v)
  (r.p + λ*r.v, λ)
end


raycast(r::Ray, planes::Vector{Plane}) = begin
  pos_λ = Inf32
  pos_hit =  Vec3f(Inf32)
  neg_λ = -Inf32
  neg_hit =  Vec3f(-Inf32)
  for s = planes
    h, λ = raycast(r, s)
    if λ >= 0
      if λ < pos_λ
        pos_λ = λ
        pos_hit = h
      end
    else
      if -λ < -neg_λ
        neg_λ = λ
        neg_hit = h
      end
    end
  end
  (pos_hit, pos_λ, neg_hit, neg_λ)
end
