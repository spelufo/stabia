import Libdl

# This reloads the library every time this file is included, for development.
# if @isdefined _snic_lib
#   Libdl.dlclose(_snic_lib)
# end
_snic_lib = Libdl.dlopen("./snic.so")
_snic = Libdl.dlsym(_snic_lib, :snic)
_snic_superpixel_count = Libdl.dlsym(_snic_lib, :snic_superpixel_count)
_snic_superpixel_max_neighs = Libdl.dlsym(_snic_lib, :snic_superpixel_max_neighs)
const SUPERPIXEL_MAX_NEIGHS = Int(@ccall $_snic_superpixel_max_neighs()::Cint)

const SuperpixelId = UInt32

# TODO: The neighbors should be returned from C in a separate array, and we can
# convert that to a julia graph. Having a fixed sized array on the struct was
# a bad idea, it complicates things for the FFI, we can't mutate it, and the
# memory overhead makes things slower when not needed. But if I change it I'll
# have to regenerate or convert all the files, which takes a while...
struct Superpixel
  x::Float32; y::Float32; z::Float32; c::Float32
  n::UInt32; nlow::UInt32; nmid::UInt32; nhig::UInt32
  neighs::NTuple{SUPERPIXEL_MAX_NEIGHS, SuperpixelId}
end

Base.zero(::Type{Superpixel}) =
  Superpixel(0f0, 0f0, 0f0, 0f0, 0, 0, 0, 0,
    NTuple{SUPERPIXEL_MAX_NEIGHS,SuperpixelId}(SuperpixelId(0) for _ in 1:SUPERPIXEL_MAX_NEIGHS))

Base.repr(spx::Superpixel) = "Superpixel(($(spx.x), $(spx.y), $(spx.z)), $(spx.c))"
Base.print(io::IO, spx::Superpixel) = write(io, repr(spx))
Base.show(io::IO, ::MIME"text/plain", spx::Superpixel) = write(io, repr(spx))

struct Superpixels <: AbstractVector{Superpixel}
  data::Vector{Superpixel}
end

Base.IndexStyle(::Type{Superpixels}) = IndexLinear()
Base.size(spxs::Superpixels) = ( length(spxs.data)-1, )
Base.length(spxs::Superpixels) = length(spxs.data)-1
Base.getindex(spxs::Superpixels, i::Integer) = spxs.data[i+1]
Base.setindex!(spxs::Superpixels, v::Superpixel, i::Integer) = setindex!(spxs.data, v, i+1)

Graphs.SimpleGraph(spxs::Superpixels) = begin
  n = length(spxs)
  g = SimpleGraph{SuperpixelId}(n)
  for (spx_src_id, spx) = enumerate(spxs)
    for spx_dst_id = Iterators.takewhile(id -> id != 0, spx.neighs)
      add_edge!(g, spx_src_id, spx_dst_id)
    end
  end
  g
end

snic(img::Array{Float32, 3}, d_seed::Int, compactness::Float32 = 100.0f0, lowmid::Float32 = 0.42f0, midhig::Float32 = 0.69f0) = begin
  ly, lx, lz = size(img)
  labels = zeros(SuperpixelId, size(img))
  superpixels_len = @ccall $_snic_superpixel_count(lx::Int, ly::Int, lz::Int, d_seed::Int)::Int
  superpixels_len += 1
  superpixels = zeros(Superpixel, superpixels_len)
  neigh_overflow = @ccall $_snic(
    img::Ptr{Float32}, lx::Int, ly::Int, lz::Int,
    d_seed::Int, compactness::Float32, lowmid::Float32, midhig::Float32,
    labels::Ptr{Float32}, superpixels::Ptr{Superpixel},
  )::Int32
  neigh_overflow == 0 || @warn "neigh_overflow == $neigh_overflow > 0, incomplete superpixel graph"
  labels, Superpixels(superpixels), d_seed, compactness
end

cell_snic_path(scan::HerculaneumScan, jy::Int, jx::Int, jz::Int) =
  joinpath(cell_segmentation_dir(scan, jy, jx, jz), "$(cell_name(jy, jx, jz))_snic.jld2")

cell_snic_labels_path(scan::HerculaneumScan, jy::Int, jx::Int, jz::Int) =
  joinpath(cell_segmentation_dir(scan, jy, jx, jz), "$(cell_name(jy, jx, jz))_snic_labels.jld2")

have_cell_snic(scan::HerculaneumScan, jy::Int, jx::Int, jz::Int) =
  isfile(cell_snic_path(scan, jy, jx, jz))

save_cell_snic(scan::HerculaneumScan, jy::Int, jx::Int, jz::Int, labels, superpixels, d_seed, compactness) = begin
  # Split in two to compress the labels. Compressing the superpixels fails.
  # TODO: Figure out how to do custom superpixel serialization, perhaps that
  # fixes it. Also, the neighs arrays we are saving are full of zeros, wasteful.
  save(cell_snic_path(scan, jy, jx, jz), "superpixels", superpixels.data, "d_seed", d_seed, "compactness", compactness)
  save(cell_snic_labels_path(scan, jy, jx, jz), "labels", labels; compress=true)
end

load_cell_snic(scan::HerculaneumScan, jy::Int, jx::Int, jz::Int) = begin
  s, d, c = load(cell_snic_path(scan, jy, jx, jz), "superpixels", "d_seed", "compactness")
  l = load(cell_snic_labels_path(scan, jy, jx, jz), "labels")
  l, Superpixels(s), d, c
end

build_snic(scan::HerculaneumScan, jy::Int, jx::Int, jz::Int) = begin
  W = convert(Array{Float32, 3}, load_cell(scan, jy, jx, jz))
  labels, superpixels, d_seed, compactness = snic(W, 10, 100f0)
  save_cell_snic(scan, jy, jx, jz, labels, superpixels, d_seed, compactness)
end

build_snic(scan::HerculaneumScan, cells::Matrix{Int64}) = begin
  n = size(cells, 1)
  for (i, (jy, jx, jz)) = enumerate(eachrow(cells))
    if have_cell_snic(scan, jy, jx, jz)
      continue
    end
    build_snic(scan, jy, jx, jz)
    println("Built snic for ($jy, $jx, $jz)\t$(round(Int,100*i/n))% done.")
  end
end

# NOTE: This is tunned to scroll 1. The c > 0.42 does most of the work (all?).
@inline superpixel_is_papyrus(spx::Superpixel) =
  spx.c > 0.42f0 && spx.nlow/spx.n < 0.50

@inline superpixel_position(spx::Superpixel) =
  Vec3f(spx.x, spx.y, spx.z)


# Visualization utils ##########################################################

mask_superpixels!(img::Array{Float32, 3}, labels::Array{SuperpixelId,3}, spxs::Superpixels) = begin
  for i in 1:length(img)
    spx_id = labels[i]
    img[i] = superpixel_is_papyrus(spxs[spx_id])
  end
  img
end

mark_boundaries!(img::Array{Float32, 3}, labels::Array{SuperpixelId,3}, color = zero(eltype(img))) = begin
  gx, gy, gz = imgradients(labels, KernelFactors.sobel);
  g = hypot.(gx, gy, gz);
  img[g .!= 0.0] .= color
  img
end

snic_edge_gradients(img::Array{Float32, 3}, labels::Array{SuperpixelId,3}, spxs::Superpixels) = begin
  out = copy(img)
  mask_superpixels!(out, labels, spxs)
  imgradients(out, KernelFactors.sobel);
end

snic_edge_grads(img::Array{Float32, 3}, labels::Array{SuperpixelId,3}, spxs::Superpixels) = begin
  gx, gy, gz = snic_edge_gradients(img, labels, spxs)
  g = hypot.(gx, gy, gz);
  g .!= 0
end

fill_superpixels!(img::Array{Float32, 3}, labels::Array{SuperpixelId,3}, spxs::Superpixels) = begin
  for i in 1:length(img)
    img[i] = spxs[labels[i]].c
  end
  img
end
