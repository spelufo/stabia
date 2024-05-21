# Root

segmentation_dir(scan::HerculaneumScan) =
  joinpath(DATA_DIR, scan.volpkg_path, "segmentation")

cell_segmentation_dir(scan::HerculaneumScan, jy::Int, jx::Int, jz::Int) =
  joinpath(segmentation_dir(scan), cell_name(jy, jx, jz))


# Probabilities (Ilastik)

cell_probabilities_path(scan::HerculaneumScan, jy::Int, jx::Int, jz::Int) =
  joinpath(cell_segmentation_dir(scan, jy, jx, jz), "$(cell_name(jy, jx, jz))_probabilities.h5")

have_cell_probabilities(scan::HerculaneumScan, jy::Int, jx::Int, jz::Int) =
  isfile(cell_probabilities_path(scan, jy, jx, jz))

load_cell_probabilities(scan::HerculaneumScan, jy::Int, jx::Int, jz::Int) = begin
  fid = h5open(cell_probabilities_path(scan, jy, jx, jz))
  P = permutedims(read(fid, "exported_data")[1,:,:,:,1], (2, 1, 3))
  close(fid)
  P
end


# Holes

cell_hole_ids_path(scan::HerculaneumScan, jy::Int, jx::Int, jz::Int) =
  joinpath(cell_segmentation_dir(scan, jy, jx, jz), "$(cell_name(jy, jx, jz))_hole_ids.h5")

cell_holes_dir(scan::HerculaneumScan, jy::Int, jx::Int, jz::Int) =
  joinpath(cell_segmentation_dir(scan, jy, jx, jz), "holes")

have_cell_holes(scan::HerculaneumScan, jy::Int, jx::Int, jz::Int) =
  isdir(cell_holes_dir(scan, jy, jx, jz))

load_cell_holes(scan::HerculaneumScan, jy::Int, jx::Int, jz::Int) = begin
  holes = []
  holes_dir = cell_holes_dir(scan, jy, jx, jz)
  for hole_filename = readdir(holes_dir)
    endswith(hole_filename, ".stl") || continue
    hole_path = joinpath(holes_dir, hole_filename)
    push!(holes, load(hole_path))
  end
  holes
end

# Patches (delete backfaces method)

cell_patches_dir(scan::HerculaneumScan, jy::Int, jx::Int, jz::Int) =
  joinpath(cell_segmentation_dir(scan, jy, jx, jz), "patches")

have_cell_patches(scan::HerculaneumScan, jy::Int, jx::Int, jz::Int) =
  isdir(cell_patches_dir(scan, jy, jx, jz))

load_cell_patches(scan::HerculaneumScan, jy::Int, jx::Int, jz::Int) = begin
  patches = []
  patches_dir = cell_patches_dir(scan, jy, jx, jz)
  for patch_filename = readdir(patches_dir)
    endswith(patch_filename, ".stl") || continue
    patch_path = joinpath(patches_dir, patch_filename)
    push!(patches, load(patch_path))
  end
  patches
end


# Patches (blender split holes method)

layer_patches_dir(scan::HerculaneumScan) =
  joinpath(DATA_DIR, scan.volpkg_path, "patches")

layer_patches_path(scan::HerculaneumScan, jz::Int) =
  joinpath(layer_patches_dir(scan), "patches_z$(zpad(jz,2)).stl")

have_layer_patches(scan::HerculaneumScan, jz::Int) =
  isfile(layer_patches_path(scan, jz))

load_layer_patches(scan::HerculaneumScan, jz::Int) =
  load(layer_patches_path(scan, jz))

# Labels

# TODO: Might deprecate or rename this, since the name collides with ink labels
# and it is very time consuming to label the potential of the split hole sheet
# faces (which I'm starting to call patches, a better name). I only did this
# for cell (11, 7, 22). This plus the potential method is how I got the best
# results so far, but it is too time consuming.

cell_labels_dir(scan::HerculaneumScan, jy::Int, jx::Int, jz::Int) =
  joinpath(cell_segmentation_dir(scan, jy, jx, jz), "labels")

have_cell_labels(scan::HerculaneumScan, jy::Int, jx::Int, jz::Int) =
  isdir(cell_labels_dir(scan, jy, jx, jz))

load_cell_labels(scan::HerculaneumScan, jy::Int, jx::Int, jz::Int) = begin
  labels = []
  labels_dir = cell_labels_dir(scan, jy, jx, jz)
  for label_filename = readdir(cell_labels_dir(scan, jy, jx, jz))
    endswith(label_filename, ".stl") || continue
    label_path = joinpath(labels_dir, label_filename)
    push!(labels, (label_filename, load(label_path)))
  end
  labels
end

# Chunks (of segment meshes split into cells and separated by winding number)

const ChunkId = UInt64

@inline chunk_segment(chunk_id::ChunkId) =
  div(chunk_id, 1000)

cell_chunks_dir(scan::HerculaneumScan, jy::Int, jx::Int, jz::Int) =
  joinpath(cell_segmentation_dir(scan, jy, jx, jz), "chunks")

have_cell_chunks(scan::HerculaneumScan, jy::Int, jx::Int, jz::Int) =
  isdir(cell_chunks_dir(scan, jy, jx, jz))

load_cell_chunks(scan::HerculaneumScan, jy::Int, jx::Int, jz::Int) = begin
  chunks = []
  chunks_dir = cell_chunks_dir(scan, jy, jx, jz)
  for chunk_filename = readdir(chunks_dir)
    endswith(chunk_filename, ".stl") || continue
    chunk_path = joinpath(chunks_dir, chunk_filename)
    chunk_id = chunk_filename[28:length(chunk_filename)-4]
    chunk_id = parse(ChunkId, replace(chunk_id, "_" => ""))
    push!(chunks, (chunk_id, load(chunk_path)))
  end
  chunks
end

cell_chunks_recon_dir(scan::HerculaneumScan, jy::Int, jx::Int, jz::Int) =
  joinpath(cell_segmentation_dir(scan, jy, jx, jz), "chunks_recon")

have_cell_chunks_recon(scan::HerculaneumScan, jy::Int, jx::Int, jz::Int) =
  isdir(cell_chunks_recon_dir(scan, jy, jx, jz))

load_cell_chunks_recon(scan::HerculaneumScan, jy::Int, jx::Int, jz::Int) = begin
  chunks = []
  chunks_dir = cell_chunks_recon_dir(scan, jy, jx, jz)
  for chunk_filename = readdir(chunks_dir)
    endswith(chunk_filename, ".stl") || continue
    chunk_path = joinpath(chunks_dir, chunk_filename)
    chunk_id = chunk_filename[42:length(chunk_filename)-4]
    chunk_id = parse(ChunkId, replace(chunk_id, "_" => ""))
    push!(chunks, (chunk_id, load(chunk_path)))
  end
  chunks
end

# Sadjs (chunks adjusted by superpixels)

cell_sadj_dir(scan::HerculaneumScan, jy::Int, jx::Int, jz::Int) =
  joinpath(cell_segmentation_dir(scan, jy, jx, jz), "sadjs")

have_cell_sadjs(scan::HerculaneumScan, jy::Int, jx::Int, jz::Int) =
  isdir(cell_sadj_dir(scan, jy, jx, jz))

load_cell_chunks_spxs(scan::HerculaneumScan, jy::Int, jx::Int, jz::Int) =
  load("$(cell_sadj_dir(scan, jy, jx, jz))/chunks_spxs.jld2", "chunks_spxs", "chunks_seq", "chunks_rem")

const FrontId = UInt64

have_cell_fronts(scan::HerculaneumScan, jy::Int, jx::Int, jz::Int) =
  isdir(cell_sadj_dir(scan, jy, jx, jz))

parse_front_name(name::String) = begin
  if endswith(name, ".ply")  name = name[1:end-4] end
  # E.g. cell_yxz_007_009_001_sadj_fronts_06_20231106155351104.
  _, _, jy, jx, jz, _, _, i, id = split(name, '_')
  jy = parse(FrontId, jy); jx = parse(FrontId, jx); jz = parse(FrontId, jz)
  # We remove the 2023 so we have enough digits in a FrontId/UInt64.
  # All segments are from 2023, and when new ones are released, it is unlikely
  # that they'll have the same timestamp mod year.
  front_id = parse(FrontId, id[5:end]) +
    jy*100000000000000000 +
      jx*1000000000000000 +
        jz*10000000000000 ;
  front_id, parse(Int, i)
end

front_id_cell(front_id::FrontId) = begin
  j = Int(div(front_id, 10000000000000))
  jz = j % 100; j = div(j, 100); jx = j % 100; jy = div(j, 100)
  (jy, jx, jz)
end

front_id_chunk_str(front_id::FrontId) = begin
  "2023" * ("$front_id"[end-12:end])
end


front_id_strs(front_id::FrontId) = begin
  s = "$front_id"
  s[1:end-13], s[end-12:end-3], s[end-2:end]
end


front_id_path(scan::HerculaneumScan, front_id::FrontId) = begin
  jy, jx, jz = front_id_cell(front_id)
  fronts_dir = cell_sadj_dir(scan, jy, jx, jz)
  chunk = front_id_chunk_str(front_id)
  for filename = readdir(fronts_dir)
    prefix = "$(cell_name(jy, jx, jz))_sadj_fronts_"
    suffix = "_$chunk.ply"
    if startswith(filename, prefix) && endswith(filename, suffix)
      return "$fronts_dir/$filename"
    end
  end
  @assert false "Front path not found for front_id $front_id."
end

load_cell_fronts(scan::HerculaneumScan, jy::Int, jx::Int, jz::Int) = begin
  fronts = []
  fronts_dir = cell_sadj_dir(scan, jy, jx, jz)
  for filename = readdir(fronts_dir)
    endswith(filename, ".ply") && contains(filename, "_sadj_fronts_") || continue
    front_path = joinpath(fronts_dir, filename)
    front_id, i = parse_front_name(filename)
    push!(fronts, (i, front_id, load(front_path)))
  end
  sort!(fronts)
  fronts
end

# Potential

cell_potential_path(scan::HerculaneumScan, jy::Int, jx::Int, jz::Int) =
  joinpath(cell_segmentation_dir(scan, jy, jx, jz), "$(cell_name(jy, jx, jz))_potential.jld2")

have_cell_potential(scan::HerculaneumScan, jy::Int, jx::Int, jz::Int) =
  isfile(cell_potential_path(scan, jy, jx, jz))

load_cell_potential(scan::HerculaneumScan, jy::Int, jx::Int, jz::Int) =
  load(cell_potential_path(scan, jy, jx, jz), "ϕ", "S")

save_cell_potential(scan::HerculaneumScan, jy::Int, jx::Int, jz::Int, ϕ, S) =
  save(cell_potential_path(scan, jy, jx, jz), "ϕ", ϕ, "S", S)

potential_sheet_dir(scan::HerculaneumScan, jy::Int, jx::Int, jz::Int) =
  joinpath(cell_segmentation_dir(scan, jy, jx, jz), "sheets")

# Normals (Heat diffusion)

cell_normals_heat_path(scan::HerculaneumScan, jy::Int, jx::Int, jz::Int) =
  joinpath(cell_segmentation_dir(scan, jy, jx, jz), "$(cell_name(jy, jx, jz))_normals_heat.jld2")

have_cell_normals_heat(scan::HerculaneumScan, jy::Int, jx::Int, jz::Int) =
  isfile(cell_normals_heat_path(scan, jy, jx, jz))

load_cell_normals_heat(scan::HerculaneumScan, jy::Int, jx::Int, jz::Int) =
  load(cell_normals_heat_path(scan, jy, jx, jz), "N")

save_cell_normals_heat(scan::HerculaneumScan, jy::Int, jx::Int, jz::Int, N) =
  save(cell_normals_heat_path(scan, jy, jx, jz), "N", N)

# Normals (FFT)

cell_normals_fft_path(scan::HerculaneumScan, jy::Int, jx::Int, jz::Int) =
  joinpath(cell_segmentation_dir(scan, jy, jx, jz), "$(cell_name(jy, jx, jz))_normals_fft.jld2")

have_cell_normals_fft(scan::HerculaneumScan, jy::Int, jx::Int, jz::Int) =
  isfile(cell_normals_fft_path(scan, jy, jx, jz))

load_cell_normals_fft(scan::HerculaneumScan, jy::Int, jx::Int, jz::Int) =
  load(cell_normals_fft_path(scan, jy, jx, jz), "N", "P")

save_cell_normals_fft(scan::HerculaneumScan, jy::Int, jx::Int, jz::Int, N, P) =
  save(cell_normals_fft_path(scan, jy, jx, jz), "N", N, "P", P)


# Derivatives (Steger)

cell_derivatives_path(scan::HerculaneumScan, jy::Int, jx::Int, jz::Int) =
  joinpath(cell_segmentation_dir(scan, jy, jx, jz), "$(cell_name(jy, jx, jz))_derivatives.jld2")

have_cell_derivatives(scan::HerculaneumScan, jy::Int, jx::Int, jz::Int) =
  isfile(cell_derivatives_path(scan, jy, jx, jz))

load_cell_derivatives(scan::HerculaneumScan, jy::Int, jx::Int, jz::Int, names) =
  load(cell_derivatives_path(scan, jy, jx, jz), names...)


# Normals (Steger)

cell_normals_steger_path(scan::HerculaneumScan, jy::Int, jx::Int, jz::Int) =
  joinpath(cell_segmentation_dir(scan, jy, jx, jz), "$(cell_name(jy, jx, jz))_normals_steger.jld2")

have_cell_normals_steger(scan::HerculaneumScan, jy::Int, jx::Int, jz::Int) =
  isfile(cell_normals_steger_path(scan, jy, jx, jz))

load_cell_normals_steger(scan::HerculaneumScan, jy::Int, jx::Int, jz::Int) =
  load(cell_normals_steger_path(scan, jy, jx, jz), "N", "r")

save_cell_normals_steger(scan::HerculaneumScan, jy::Int, jx::Int, jz::Int, N, r) =
  save(cell_normals_steger_path(scan, jy, jx, jz), "N", N, "r", r)

cell_normals_relaxed_path(scan::HerculaneumScan, jy::Int, jx::Int, jz::Int) =
  cell_normals_steger_path(scan, jy, jx, jz)

have_cell_normals_relaxed(scan::HerculaneumScan, jy::Int, jx::Int, jz::Int) =
  have_cell_normals_steger(scan, jy, jx, jz)

load_cell_normals_relaxed(scan::HerculaneumScan, jy::Int, jx::Int, jz::Int) =
  load(cell_normals_steger_path(scan, jy, jx, jz), "Nr", "rr")

save_cell_normals_relaxed(scan::HerculaneumScan, jy::Int, jx::Int, jz::Int, Nr, rr) =
  jldopen(cell_normals_steger_path(scan, jy, jx, jz), "a+") do f
    f["Nr"] = Nr
    f["rr"] = rr
  end


# Thaumato Mask3D colorized point clouds

tmpc_path(scan::HerculaneumScan) =
  joinpath(scan.volpkg_path, "scroll1_surface_points", "point_cloud_colorized_verso_subvolume_blocks")

tmpc_dir(scan::HerculaneumScan) =
  joinpath(DATA_DIR, tmpc_path(scan))


px_to_tmpc(x) = x/4 + 125
tmpc_to_px(x) = (x - 125)*4
cell_tmpc(jx) = Int.(px_to_tmpc.(((jx-1)*500:100:jx*500).-100))

download_cell_tmpcs(scan::HerculaneumScan, jy::Int, jx::Int, jz::Int) = begin
  for y = cell_tmpc(jy), z = cell_tmpc(jz), x = cell_tmpc(jx)
    path = "$(tmpc_path(scan))/$(zpad(y,6))_$(zpad(z,6))_$(zpad(x,6)).tar"
    download_file(path)
  end
end

untar_cell_tmpcs(scan::HerculaneumScan, jy::Int, jx::Int, jz::Int) = begin
  dir = pwd()
  cd(tmpc_dir(scan))
  for y = cell_tmpc(jy), z = cell_tmpc(jz), x = cell_tmpc(jx)
    name = "$(zpad(y,6))_$(zpad(z,6))_$(zpad(x,6))"
    isdir(name) || run(`tar --one-top-level -xf $name.tar`)
  end
  cd(dir)
end

print_blender_import_cell_tmpcs(scan::HerculaneumScan, jy::Int, jx::Int, jz::Int; io::IO=stdout) = begin
  println(io, "import bpy")
  println(io, "from vesuvius.utils import activate_collection")
  colname = "$(cell_name(jy, jx, jz))_tmpcs"
  println(io, "rootcol = activate_collection($(repr(colname)))")
  for y = cell_tmpc(jy)[1:2:end], z = cell_tmpc(jz)[1:1], x = cell_tmpc(jx)[1:2:end]
    name = "$(zpad(y,6))_$(zpad(z,6))_$(zpad(x,6))"
    tmpcs_dir = "$(tmpc_dir(scan))/$name"
    println(io, "col = activate_collection($(repr(name)), parent_collection=rootcol)")
    plys = filter(x->endswith(x, ".ply"), readdir(tmpcs_dir))
    print_blender_imports(map(x->joinpath(tmpcs_dir, x), plys),
      io=io, params="global_scale=0.04, forward_axis='X', up_axis='Y'")
  end
end

# Ryan's 3d ink predictions

cell_inkblocks(cells) = begin
  blocks = Set{Tuple{Int,Int,Int}}()
  for (jy, jx, jz) = cells
    ry = cell_range(jy).-1
    rx = cell_range(jx).-1
    rz = cell_range(jz).-1
    for by = div(ry.start,256):div(ry.stop,256), bx = div(rx.start,256):div(rx.stop,256), bz = div(rz.start,256):div(rz.stop,256)
      push!(blocks, (by, bx, bz))
    end
  end
  blocks
end

download_inkblocks_jzs(jzs) = begin
  blocks = cell_inkblocks(filter(j -> j[3]∈jzs, eachrow(scroll_1_54_gp_mask)))
  n = length(blocks)
  path = "community-uploads/ryan/3d_predictions_scroll1.zarr"
  dir = joinpath(DATA_DIR, path)
  isdir(dir) || mkpath(dir)
  for (i, (by, bx, bz)) = enumerate(blocks)
    println("Downloading block $by.$bx.$bz ($i/$n)...")
    isfile("$dir/$by.$bx.$bz") || download_file("$path/$by.$bx.$bz")
  end
end
