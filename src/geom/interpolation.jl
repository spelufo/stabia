@inline interpolate_trilinear(V::Array{E, 3}, p::Vec{3, F}) where {E, F} = begin
  q = p .+ 0.5f0
  i = floor.(q)
  λ = q - i
  x, y, z = Int.(i)

  # https://en.wikipedia.org/wiki/Trilinear_interpolation
  c00 = λ[2] * V[y, x, z]         + (1f0 - λ[2]) * V[y + 1, x, z]
  c01 = λ[2] * V[y, x, z + 1]     + (1f0 - λ[2]) * V[y + 1, x, z + 1]
  c10 = λ[2] * V[y, x + 1, z]     + (1f0 - λ[2]) * V[y + 1, x + 1, z]
  c11 = λ[2] * V[y, x + 1, z + 1] + (1f0 - λ[2]) * V[y + 1, x + 1, z]
  c0 = λ[1] * c00  + (1f0 - λ[1]) * c10
  c1 = λ[1] * c01  + (1f0 - λ[1]) * c11
  c = λ[3] * c0 + (1f0 - λ[3]) * c1
  c
end


"""
Find a cuadratic curve γ(t) = (ax*t^2 + bx*t + p0x, ..., az*t^2 + bz*t + p0z)
that passes through p0 = γ(0), is normal to n0 at p0, and is normal to the (π1, n1)
plane at a point p1 = γ(1). Returns a tuple (γ, p1) such that γ*[t^2,t,1] = γ(t).
"""
curve_normal_to_planes(p0::Vec3f, n0::Vec3f, π1::Vec3f, n1::Vec3f) = begin
  # w = [ax, ay, az, bx, by, bz, p1x, p1y, p1z, λ]
  A = Float32[
    # γ′(0) = λ n0 = [bx, by, bz]
    0    0    0    1    0    0     0     0     0    -n0[1] ;
    0    0    0    0    1    0     0     0     0    -n0[2] ;
    0    0    0    0    0    1     0     0     0    -n0[3] ;
    # γ(1) = p1 = [ax+bx+p0x, ay+by+p0y, az+bz+p0z] = [p1x, p1y, p1z]
    1    0    0    1    0    0    -1     0     0      0    ;
    0    1    0    0    1    0     0    -1     0      0    ;
    0    0    1    0    0    1     0     0    -1      0    ;
    # γ′(1) = λ n1 = [2ax+bx, 2ay+by, 2az+bz]
    2    0    0    1    0    0     0     0     0    -n1[1] ;
    0    2    0    0    1    0     0     0     0    -n1[2] ;
    0    0    2    0    0    1     0     0     0    -n1[3] ;
    # dot(p1 - π1, n1) = 0 <-> dot(p1, n1) = dot(π1, n1)
    0    0    0    0    0    0   n1[1] n1[2] n1[3]    0    ;
  ]
  b = Float32[0, 0, 0, -p0[1], -p0[2], -p0[3], 0, 0, 0, dot(π1, n1)]
  w = A \ b
  p1 = Vec3f(w[7], w[8], w[9])
  γ = [
    w[1] w[4] p0[1];
    w[2] w[5] p0[2];
    w[3] w[6] p0[3];
  ]
  γ, p1
end
