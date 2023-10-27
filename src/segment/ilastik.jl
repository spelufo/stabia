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

run_ilastic_classification(scan::HerculaneumScan, jy::Int, jx::Int, jz::Int) = begin
  cell_h5 = cell_h5_path(scan, jy, jx, jz)
  if !isfile(cell_h5)
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
      $cell_h5`,
      stdout="/tmp/ilastik_pixel_classification.log",
      stderr="/tmp/ilastik_pixel_classification.log"))
  end
end
