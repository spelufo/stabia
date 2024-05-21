using PackageCompiler

packages = [
  "Base64",
  "JSON",
  "Downloads",
  "LinearAlgebra",
  "Random",
  "Quaternions",
  "StaticArrays",
  "GeometryBasics",
  "FFTW",

  "MarchingCubes",
  "DataStructures",
  "Graphs", "SimpleWeightedGraphs",

  "FileIO",
  "Interpolations",
  "Images", "ImageFiltering", "ImageTracking", "TiffImages",
  "HDF5",
  "JLD2", "CodecZlib",
]

println("Creating sysimage...")
PackageCompiler.create_sysimage(
  packages; sysimage_path=joinpath(dirname(@__DIR__), "stabia_sysimage.so"))
println("Done.")
