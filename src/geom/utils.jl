

@inline gpu_ceil(x::Int) = begin
  np = nextpow(2, x)
  np - x < 32 ? np : (div(x, 2)+1)*2
end

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
