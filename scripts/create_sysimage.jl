using PackageCompiler

packages = [
  "Base64",
  "Downloads",
  "LinearAlgebra",
  "StaticArrays",
  "Quaternions",
  "GeometryBasics",
  "FFTW",
  "Images",
  "ImageFiltering",
  "FileIO",
  "TiffImages",
  "JLD2",
]

println("Creating sysimage...")
PackageCompiler.create_sysimage(
  packages;
  sysimage_path=joinpath(dirname(@__DIR__), "stabia_sysimage.so"),
  # precompile_execution_file=joinpath(@__DIR__, "create_sysimage_precompile.jl")
  )
println("Done.")
