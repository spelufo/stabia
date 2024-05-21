

@inline gpu_ceil(x::Int) = begin
  np = nextpow(2, x)
  np - x < 32 ? np : (div(x, 2)+1)*2
end

@inline norm_squared(v::Vec3f) =
  dot(v, v)
