# There's a lot we could do here with different kinds of objects, object
# collections, hide/show objects, etc. But resiste the temptation as much
# as possible, keep it simple!

abstract type SceneObject end

Base.@kwdef mutable struct Scene
  objects :: Vector{SceneObject}
end

ScratchScene() =
  Scene([
    StaticBoxMesh(zero(Vec3f), Vec3f(1f0, 1f0, 1f0)),
  ])


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
