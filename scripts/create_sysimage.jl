using PackageCompiler

packages = [
  # Base packages.
  "Base64",
  "Downloads",
  "LinearAlgebra",
  "Quaternions",
  "StaticArrays",
  "GeometryBasics",
  "FFTW",

  # IO and images packages.
  "FileIO",
  "Images",
  "ImageFiltering",
  "TiffImages",
  "HDF5",
  "JLD",
]

println("Creating sysimage...")
PackageCompiler.create_sysimage(
  packages;
  sysimage_path=joinpath(dirname(@__DIR__), "stabia_sysimage.so"),
  precompile_execution_file=joinpath(@__DIR__, "create_sysimage_precompile.jl"))
println("Done.")
