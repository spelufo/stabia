

slice_small_cell(V::Array{Gray{N0f16},3}, jy::Int, jx::Int, jz::Int) = begin
  V[(jy-1)*50+1:jy*50, (jx-1)*50+1:jx*50, (jz-1)*50+1:jz*50]
end


compute_sparcity(V::Array{Float32,3}) = begin
  S = zeros(Float32, floor.(Int, size(V)./ 50))
  for jz = 1:size(S,3), jx = 1:size(S,2), jy = 1:size(S,1)
    S[jy,jx,jz] = count(c -> c > 0.5f0, V[(jy-1)*50+1:jy*50, (jx-1)*50+1:jx*50, (jz-1)*50+1:jz*50]) / 50^3
  end
  S
end
