import Libdl

# This reloads the library every time this file is included, for development.
if @isdefined _recon_lib
  Libdl.dlclose(_recon_lib)
end
_recon_lib = Libdl.dlopen("./recon.so")
_poisson_recon = Libdl.dlsym(_recon_lib, :poisson_recon)

const Cbool = Cuchar

Base.@kwdef struct PoissonReconSolutionParameters
  verbose::Cbool = false
  dirichletErode::Cbool = false
  outputDensity::Cbool = false
  exactInterpolation::Cbool = false
  showResidual::Cbool = false
  scale::Float32 = 1.1f0
  confidence::Float32 = 0f0
  confidenceBias::Float32 = 0f0
  lowDepthCutOff::Float32 = 0f0
  width::Float32 = 0f0
  pointWeight::Float32 = 0f0
  valueInterpolationWeight::Float32 = 0f0
  samplesPerNode::Float32 = 1.5f0
  cgSolverAccuracy::Float32 = 1f-3
  depth::UInt32 = 6
  solveDepth::UInt32 = 0xffff_ffff
  baseDepth::UInt32 = 0xffff_ffff
  fullDepth::UInt32 = 5
  kernelDepth::UInt32 = 0xffff_ffff
  envelopeDepth::UInt32 = 0xffff_ffff
  baseVCycles::UInt32 = 1
  iters::UInt32 = 8
end

Base.@kwdef struct PoissonReconLevelSetExtractionParameters
  linearFit::Cbool = false
  outputGradients::Cbool = false
  forceManifold::Cbool = true
  polygonMesh::Cbool = false
  verbose::Cbool = false
end

poisson_recon_ccall(
  ps::Vector{Vec3f}, ns::Vector{Vec3f},
  out_path::String,
  solver_params::PoissonReconSolutionParameters,
  extraction_params::PoissonReconLevelSetExtractionParameters
) = begin
  @assert length(ps) == length(ns) "size of points and normals must match"
  n = UInt32(length(ps))
  @ccall $_poisson_recon(
    n::UInt32, ps::Ptr{Vec3f}, ns::Ptr{Vec3f}, out_path::Cstring,
    solver_params::PoissonReconSolutionParameters,
    extraction_params::PoissonReconLevelSetExtractionParameters
  )::Cvoid
end

poisson_recon(
  ps::Vector{Vec3f}, ns::Vector{Vec3f}, bbox_min::Vec3f, bbox_width::Float32, out_path::String;
  depth = 6) = begin
  ps_unit = (ps .- bbox_min)./bbox_width
  poisson_recon_ccall(ps_unit, ns, out_path,
    PoissonReconSolutionParameters(scale=0, depth=UInt32(depth)),
    PoissonReconLevelSetExtractionParameters())
end

poisson_recon(
  mesh::Mesh, bbox_min::Vec3f, bbox_width::Float32,
  out_path::String; kwargs...
) = begin
  ps = convert(Vector{Vec3f}, metafree(coordinates(mesh)))
  ns = normals(mesh)
  poisson_recon(ps, ns, bbox_min, bbox_width, out_path; kwargs...)
end
