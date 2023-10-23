using PackageCompiler

packages = [
  # Base packages.
  "Base64",
  "Downloads",
  "LinearAlgebra",
  "Quaternions",
  "StaticArrays",
  "GeometryBasics",

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
  sysimage_path=joinpath(@__DIR__, "stabia_deps_sysimage.so"),
  precompile_execution_file=joinpath(@__DIR__, "stabia_deps.jl"))
println("Done.")
