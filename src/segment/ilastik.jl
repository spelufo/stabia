include("../core/core.jl")
include("meshing.jl")

ILASTIK_DIR = "/mnt/phil/vesuvius/ilastik"

ILASTIK_PROJECTS_PC = Dict{String,String}(
  scroll_1_54.id   => joinpath(ILASTIK_DIR, "PixelClassification_06_08_17.ilp"),
  pherc_1667_88.id => joinpath(ILASTIK_DIR, "PixelClassification_pherc_1667_09_11_23.ilp"),
)
ILASTIK_PROJECTS_OC = Dict{String,String}(
  scroll_1_54.id   => joinpath(ILASTIK_DIR, "ObjectClassification_06_08_17.ilp"),
  pherc_1667_88.id => joinpath(ILASTIK_DIR, "ObjectClassification_pherc_1667_09_11_23.ilp"),
)

# File Conversion

"""
  cell_to_h5(inputfile::String, outputfile::String)

Convert a cell tif volume file (e.g. "cell_yxz_001_001_001.tif") to HDF5 for loading in Ilastik.
"""
cell_to_h5(inputfile::String, outputfile::String) = begin
  if isfile(outputfile) return nothing end
  V = TiffImages.load(inputfile).data
  save_ilastik_h5(V, outputfile)
end

save_ilastik_h5(V::Array{Gray{N0f16},3}, outputfile::String) = begin
  # ilastik's txyzc coords order
  W = Array{UInt16, 5}(undef, (1, size(V, 2), size(V, 1), size(V, 3), 1))
  for iz = 1:size(V, 3), ix = 1:size(V, 2), iy = 1:size(V, 1)
    W[1, ix, iy, iz, 1] = V[iy, ix, iz].val.i
  end
  h5open(outputfile, "w") do f
    f["data", chunk=(1, 64, 64, 64, 1)] = W  # ilastik wants chunked hdf5
  end
  nothing
end

cell_to_h5(scan::HerculaneumScan, jy::Int, jx::Int, jz::Int) = begin
  h5_path = cell_h5_path(scan, jy, jx, jz)
  if !isdir(dirname(h5_path))
    mkdir(dirname(dirname(h5_path)))
    mkdir(dirname(h5_path))
  end
  cell_to_h5(
    cell_path(scan, jy, jx, jz),
    cell_h5_path(scan, jy, jx, jz),
  )
end

# Pixel classification

run_ilastik_classification(scan::HerculaneumScan, jy::Int, jx::Int, jz::Int) = begin
  cell_h5_file = cell_h5_path(scan, jy, jx, jz)
  if !isfile(cell_h5_file)
    cell_to_h5(scan, jy, jx, jz)
  end
  probabilities_file = cell_probabilities_path(scan, jy, jx, jz)
  if !isfile(probabilities_file)
    println("Running ilastik pixel classification...")
    run(pipeline(
      `/opt/ilastik/run_ilastik.sh --project $(ILASTIK_PROJECTS_PC[scan.id])
      --headless --readonly
      --export_source Probabilities
      --output_filename_format $probabilities_file
      $cell_h5_file`,
      stdout="/tmp/ilastik_pixel_classification.log",
      stderr="/tmp/ilastik_pixel_classification.log"))
  end
end


# Object classification

run_ilastik_hole_ids(scan::HerculaneumScan, jy::Int, jx::Int, jz::Int) = begin
  cell_h5_file = cell_h5_path(scan, jy, jx, jz)
  probabilities_file = cell_probabilities_path(scan, jy, jx, jz)
  if !isfile(cell_h5_file)
    cell_to_h5(scan, jy, jx, jz)
  end
  if !isfile(probabilities_file)
    run_ilastik_classification(scan, jy, jx, jz)
  end
  hole_ids_file = cell_hole_ids_path(scan, jy, jx, jz)
  if !isfile(hole_ids_file)
    println("Running ilastik segmentation...")
    run(pipeline(
      `/opt/ilastik/run_ilastik.sh --project $(ILASTIK_PROJECTS_OC[scan.id])
      --headless --readonly
      --export_source 'Object Identities'
      --output_filename_format $hole_ids_file
      --raw_data $cell_h5_file
      --prediction_maps $probabilities_file`,
      stdout="/tmp/ilastik_segmentation.log",
      stderr="/tmp/ilastik_segmentation.log"))
  end
end


# Mesh holes

run_ilastik_mesh_holes(scan::HerculaneumScan, jy::Int, jx::Int, jz::Int) = begin
  hole_ids_file = cell_hole_ids_path(scan, jy, jx, jz)
  if !isfile(hole_ids_file)
    run_ilastik_hole_ids(scan, jy, jx, jz)
  end
  hole_dir = cell_holes_dir(scan, jy, jx, jz)
  if !isdir(hole_dir)
    println("Building hole meshes...")
    mkdir(hole_dir)
    cell_pos = Point3f(500f0 * (jx-1), 500f0 * (jy-1), 500f0 * (jz-1))
    hole_ids_to_meshes(hole_ids_file, "$hole_dir/$(cell_name(jy, jx, jz))_hole_", cell_pos)

    # Clean up intermediate files to save space. We don't remove the
    # probabilities.h5 file, that one could come in handy down the line.
    rm(hole_ids_file)
    rm(cell_h5_path(scan, jy, jx, jz))
  end
end


run_ilastik_mesh_holes(scan::HerculaneumScan, cells) = begin
  n_total = length(cells)
  remaining_cells = filter(c -> !have_cell_holes(scan, c...), cells)
  n_remaining = length(remaining_cells)
  @show n_total n_remaining

  i = 1
  for (jy, jx, jz) in remaining_cells
    println("Running ilastik_mesh_holes on cell $((jy, jx, jz))  ($i/$n_remaining)...")
    run_ilastik_mesh_holes(scan, jy, jx, jz)
    println("Done running ilastik_mesh_holes on cell $((jy, jx, jz)).\n\n")
    GC.gc()
    space = parse(Int, split(read(`df --output=avail /mnt/phil/`, String), "\n")[2])
    if space < 10*1024*1024
      println("Too little space left on drive, aborting.")
      break
    end
    println()
    sleep(3)
    i += 1
    if i % 20 == 0
      sleep(120)
    end
  end
end



# Chunk pherc_1667_88 small for ilastik.
# build_pherc_1667_88_h5_chunks() = begin
#   V = load_small_volume(pherc_1667_88)
#   c = div.(size(V), 2)
#   n = div.(size(V), 500)
#   r = map((cx, nx) -> cx - div(500*nx, 2) + 1 : 500 : cx + div(500*nx, 2), c, n)
#   for iz0 = r[3], ix0 = r[2], iy0 = r[1]
#     v = V[iy0:iy0+499, ix0:ix0+499, iz0:iz0+499]
#     filename = "chunk_y$(zpad(iy0, 5))_x$(zpad(ix0, 5))_z$(zpad(iz0, 5)).h5"
#     save_ilastik_h5(v, joinpath(DATA_DIR, pherc_1667_88.volpkg_path, "volumes_small", filename))
#   end
# end


