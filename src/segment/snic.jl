import Libdl

# This reloads the library every time this file is included, which is fine for
# development. TODO: Rip it out.
if @isdefined _snic_lib
  Libdl.dlclose(_snic_lib)
end
_snic_lib = Libdl.dlopen("./snic.so")
_snic = Libdl.dlsym(_snic_lib, :snic)
_snic_superpixel_count = Libdl.dlsym(_snic_lib, :snic_superpixel_count)
_snic_superpixel_max_neighs = Libdl.dlsym(_snic_lib, :snic_superpixel_max_neighs)
const SUPERPIXEL_MAX_NEIGHS = Int(@ccall $_snic_superpixel_max_neighs()::Cint)

struct Superpixel
  x::Float32; y::Float32; z::Float32; c::Float32
  n::UInt32; nlow::UInt32; nmid::UInt32; nhig::UInt32
  neighs::NTuple{SUPERPIXEL_MAX_NEIGHS, UInt32}
end

Base.zero(::Type{Superpixel}) =
  Superpixel(0f0, 0f0, 0f0, 0f0, 0, 0, 0, 0,
    NTuple{SUPERPIXEL_MAX_NEIGHS,UInt32}(UInt32(0) for _ in 1:SUPERPIXEL_MAX_NEIGHS))

snic(img::Array{Float32, 3}, d_seed::Int, compactness::Float32 = 100.0f0, lowmid::Float32 = 0.42f0, midhig::Float32 = 0.69f0) = begin
  ly, lx, lz = size(img)
  labels = zeros(UInt32, size(img))
  superpixels_len = @ccall $_snic_superpixel_count(lx::Int, ly::Int, lz::Int, d_seed::Int)::Int
  superpixels_len += 1
  superpixels = zeros(Superpixel, superpixels_len)
  neigh_overflow = @ccall $_snic(
    img::Ptr{Float32}, lx::Int, ly::Int, lz::Int,
    d_seed::Int, compactness::Float32, lowmid::Float32, midhig::Float32,
    labels::Ptr{Float32}, superpixels::Ptr{Superpixel},
  )::Int32
  neigh_overflow == 0 || @warn "neigh_overflow == $neigh_overflow > 0, incomplete superpixel graph"
  labels, superpixels
end


mask_superpixels!(img::Array{Float32, 3}, labels::Array{UInt32,3}, superpixels::Vector{Superpixel}) = begin
  for i in 1:length(img)
    l = labels[i]+1
    img[i] = superpixels[l].c > 0.42f0 && superpixels[l].nlow/superpixels[l].n < 0.50
  end
  img
end


mark_boundaries!(img::Array{Float32, 3}, labels::Array{UInt32,3}, color = zero(eltype(img))) = begin
  gx, gy, gz = imgradients(labels, KernelFactors.sobel);
  g = hypot.(gx, gy, gz);
  img[g .!= 0.0] .= color
  img
end

snic_edge_gradients(img::Array{Float32, 3}, labels::Array{UInt32,3}, superpixels::Vector{Superpixel}) = begin
  out = copy(img)
  mask_superpixels!(out, labels, superpixels)
  imgradients(out, KernelFactors.sobel);
end

snic_edge_grads(img::Array{Float32, 3}, labels::Array{UInt32,3}, superpixels::Vector{Superpixel}) = begin
  gx, gy, gz = snic_edge_gradients(img, labels, superpixels)
  g = hypot.(gx, gy, gz);
  g .!= 0
end

fill_superpixels!(img::Array{Float32, 3}, labels::Array{UInt32,3}, superpixels::Vector{Superpixel}) = begin
  for i in 1:length(img)
    img[i] = superpixels[labels[i]+1].c
  end
  img
end

