# This file is run when building a sysimage. The point is to run functions from
# the packages we will use to trigger precompilation of the functions we will
# use. I think the packages will be precompiled anyway by our call to
# create_sysimage, but the specialization that happens when our code calls those
# packages isn't necessarily precompiled. So for example we want tiff loading to
# be as fast as possible so we run that here before the sysimage is built, only
# so that all the type specific method compilation that the call triggers is
# done before creating the sysimage, thus saving this compilations too.

using Base64
using Downloads
using LinearAlgebra
using Quaternions
using StaticArrays
using GeometryBasics

using FileIO
using Images
using ImageFiltering
using TiffImages
using HDF5
using JLD

# Does this mean that core would be baked in too?
# In that case maybe I shouldn't do this...
include("../core/core.jl")

println("Running stabia_deps.jl, load_small_volume")
scroll_1_small = load_small_volume(scroll_1_54)
println("Done")

nothing
