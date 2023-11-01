

@inline gpu_ceil(x::Int) = begin
  np = nextpow(2, x)
  np - x < 32 ? np : (div(x, 2)+1)*2
end
