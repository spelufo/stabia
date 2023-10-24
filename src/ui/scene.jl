# There's a lot we could do here with different kinds of objects, object
# collections, hide/show objects, etc. But resiste the temptation as much
# as possible, keep it simple!

abstract type SceneObject end

Base.@kwdef mutable struct Scene
  scanvol :: ScanVolume
  objects :: Vector{SceneObject}
  camera :: Camera
end

Scene(scroll::HerculaneumScan) = begin
  scanvol = ScanVolume(scroll)
  dims = dimensions(scanvol)
  objects = [
    # StaticBoxMesh(zero(Vec3f), Vec3f(dims[1], dims[2], dims[3]/2f0)),
    # StaticBoxMesh(zero(Vec3f), Vec3f(1f0, 1f0, 1f0)),
  ]
  # camera = PerspectiveCamera(dims, 0.5f0 * dims, Vec3f(0f0, 0f0, 1f0), 1)
  camera = PerspectiveCamera(Vec3f(2, 2, 0), zero(Vec3f), Vec3f(0, 0, 1), 1f0)
  Scene(scanvol, objects, camera)
end

mutable struct StaticMesh <: SceneObject
  pose :: Pose
  mesh :: GLMesh
end

StaticBoxMesh(p0::Vec3f, p1::Vec3f) =
  StaticMesh(Pose(p0), GLBoxMesh(zero(Vec3f), p1 - p0))

StaticQuadMesh(p::Vec3f, n::Vec3f, up::Vec3f, w::Float32, h::Float32) = begin
  u = cross(n, up)
  v = cross(u, n)
  p1 = p + w*u
  p3 = p - w*u
  p2 = p + h*v
  p4 = p - h*v
  StaticMesh(Pose(p), GLQuadMesh(p1, p2, p3, p4))
end

draw!(mesh::StaticMesh) = begin
  # TODO: Object transform uniform.
  draw!(mesh.mesh)
end
