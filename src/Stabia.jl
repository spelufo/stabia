using StaticArrays, GeometryBasics, Images, TiffImages, FileIO, HDF5

include("utils/utils.jl")
include("core/core.jl")

include("segmentation/ilastik.jl")
include("segmentation/normals_field.jl")

include("ui/main.jl")

# schedule(Task(main))

