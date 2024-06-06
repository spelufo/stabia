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
  outputDensity::Cbool = true
  exactInterpolation::Cbool = false
  showResidual::Cbool = false
  scale::Float32 = 1.1f0
  confidence::Float32 = 0f0
  confidenceBias::Float32 = 0f0
  lowDepthCutOff::Float32 = 0f0
  width::Float32 = 0f0
  pointWeight::Float32 = 2.0f0
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
  outputGradients::Cbool = true
  forceManifold::Cbool = true
  polygonMesh::Cbool = false
  verbose::Cbool = false
end

poisson_recon_ccall(ps::Vector{Point3f}, ns::Vector{Vec3f}, solver_params::PoissonReconSolutionParameters, extraction_params::PoissonReconLevelSetExtractionParameters) = begin
  @assert length(ps) == length(ns) "size of points and normals must match"
  n = UInt32(length(ps))

  # Won't work on ARM according to https://docs.julialang.org/en/v1/manual/calling-c-and-fortran-code/#Closure-cfunctions
  # Also, perf: How bad is it? Do we care?
  # TODO: Maybe lift the callbacks to global scope and reuse the output arrays.
  # It wouldn't be thread-safe without locking...

  vert_ps = Point3f[]
  vert_ns = Vec3f[]
  vert_densities = Float32[]
  vert_new(x::Float32, y::Float32, z::Float32, nx::Float32, ny::Float32, nz::Float32, d::Float32) = begin
    push!(vert_ps, Point3f(x, y, z))
    push!(vert_ns, Vec3f(nx, ny, nz))
    push!(vert_densities, d)
    nothing
  end
  c_vert_new = @cfunction($vert_new, Cvoid, (Float32, Float32, Float32, Float32, Float32, Float32, Float32))

  tris = GLTriangleFace[]
  tri_new(a::UInt32, b::UInt32, c::UInt32) = begin
    push!(tris, GLTriangleFace(
      reinterpret(ZeroIndex{UInt32}, a),
      reinterpret(ZeroIndex{UInt32}, b),
      reinterpret(ZeroIndex{UInt32}, c)))
    nothing
  end
  c_tri_new = @cfunction($tri_new, Cvoid, (UInt32, UInt32, UInt32))

  polys = Vector{ZeroIndex{UInt32}}[]
  poly_new(nverts::UInt64) = begin
    poly = Vector{UInt32}(undef, nverts)
    resize!(poly, 0)
    push!(polys, poly)
    nothing
  end
  poly_index(i::UInt32) = begin
    push!(polys[length(polys)], reinterpret(ZeroIndex{UInt32},i))
    nothing
  end
  c_poly_new = @cfunction($poly_new, Cvoid, (UInt64,))
  c_poly_index = @cfunction($poly_index, Cvoid, (UInt32,))

  @ccall $_poisson_recon(
    n::UInt32, ps::Ptr{Point3f}, ns::Ptr{Vec3f},
    c_vert_new::Ptr{Cvoid}, c_tri_new::Ptr{Cvoid}, c_poly_new::Ptr{Cvoid}, c_poly_index::Ptr{Cvoid},
    solver_params::PoissonReconSolutionParameters,
    extraction_params::PoissonReconLevelSetExtractionParameters
  )::Cvoid

  # TODO: Figure out how to build a Mesh with ngons if we need to.
  @assert length(polys) == 0 "ngons not implemented, only triangles"

  vert_ps, vert_ns, vert_densities, tris
end

poisson_recon(ps::Vector{Point3f}, ns::Vector{Vec3f}, bbox_min::Vec3f, bbox_width::Float32; depth = 6) = begin
  ps_unit = copy(ps)
  for (i, p) = enumerate(ps_unit)  ps_unit[i] = (p - bbox_min)/bbox_width  end
  solver_params = PoissonReconSolutionParameters(scale=0, depth=UInt32(depth))
  extraction_params = PoissonReconLevelSetExtractionParameters()
  vert_ps, vert_ns, vert_densities, tris = poisson_recon_ccall(ps_unit, ns, solver_params, extraction_params)
  for (i, p) = enumerate(vert_ps)  vert_ps[i] = bbox_width*p + bbox_min  end
  vert_ps, vert_ns, vert_densities, tris
end

poisson_recon(mesh::Mesh, bbox_min::Vec3f, bbox_width::Float32; kwargs...) = begin
  ps = metafree(coordinates(mesh))
  ns = normals(mesh)
  vert_ps, vert_ns, vert_densities, tris = poisson_recon(ps, ns, bbox_min, bbox_width; kwargs...)
  Mesh(meta(vert_ps; normals=vert_ns), tris)
end
