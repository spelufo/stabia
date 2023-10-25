# These packages are assumed available all over the codebase.
# They can be precompiled in a sysimage. See scripts/create_sysimage.jl
using StaticArrays, GeometryBasics, FFTW, Images
using FileIO, TiffImages, JLD2

include("geom/geom.jl")
include("core/core.jl")
include("segmentation/segmentation.jl")
include("ui/main.jl")

# schedule(Task(main))

