include("../core/core.jl")
include("ilastik_objids_to_meshes.jl")

ILASTIK_PROJECT_PC = "/mnt/phil/vesuvius/ilastik/PixelClassification_06_08_17.ilp"
ILASTIK_PROJECT_OC = "/mnt/phil/vesuvius/ilastik/ObjectClassification_06_08_17.ilp"


# File Conversion

"""
  cell_to_h5(inputfile::String, outputfile::String)

Convert a cell tif volume file (e.g. "cell_yxz_001_001_001.tif") to HDF5 for loading in Ilastik.
"""
cell_to_h5(inputfile::String, outputfile::String) = begin
  if isfile(outputfile) return nothing end
  V = load(inputfile)
  W = reinterpret.(UInt16, gray.(V))         # -> UInt16[]
  X = permutedims(W, (2, 1, 3))              # yxz -> xyz
  Y = reshape(X, (1, size(X)..., 1))         # ilastik's txyzc coords order
  h5open(outputfile, "w") do f
    f["data", chunk=(1, 64, 64, 64, 1)] = Y  # ilastik wants chunked hdf5
  end
  nothing
end

cell_to_h5(scan::HerculaneumScan, jy::Int, jx::Int, jz::Int) =
  cell_to_h5(
    cell_path(scan, jy, jx, jz),
    cell_h5_path(scan, jy, jx, jz),
  )


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
      `/opt/ilastik/run_ilastik.sh --project $ILASTIK_PROJECT_PC
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
  if !isfile(probabilities_file)
    run_ilastik_classification(scan, jy, jx, jz)
  end
  hole_ids_file = cell_hole_ids_path(scan, jy, jx, jz)
  if !isfile(hole_ids_file)
    println("Running ilastik segmentation...")
    run(pipeline(
      `/opt/ilastik/run_ilastik.sh --project $ILASTIK_PROJECT_OC
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
  end
end
