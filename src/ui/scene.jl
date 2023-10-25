# There's a lot we could do here with different kinds of objects, object
# collections, hide/show objects, etc. But resiste the temptation as much
# as possible, keep it simple!

abstract type SceneObject end

mutable struct Scene
  scanvol :: ScanVolume
  objects :: Vector{SceneObject}
end

# Not called by main(), for things that we want to persist, like scan data.
Scene(scroll::HerculaneumScan) = begin
  scanvol = ScanVolume(scroll)
  dims = dimensions(scanvol)
  objects = [
    # StaticBoxMesh(E0, Vec3f(dims[1], dims[2], dims[3]/2f0)),
    # StaticBoxMesh(E0, Vec3f(1f0, 1f0, 1f0)),
  ]
  Scene(scanvol, objects)
end

# Called by main(), fort things to reset when a new window/editor is created.
init!(scene::Scene) = begin
  scene.scanvol.small_texture = 0
  scene.scanvol.cell_texture = 0
end

mutable struct StaticMesh <: SceneObject
  pose :: Pose
  mesh :: GLMesh
end

StaticBoxMesh(p0::Vec3f, p1::Vec3f) =
  StaticMesh(Pose(p0), GLBoxMesh(zero(Vec3f), p1 - p0))
  # StaticMesh(Pose(Vec3f(0f0)), GLBoxMesh(p0, p1))

StaticQuadMesh(p::Vec3f, n::Vec3f, up::Vec3f, w::Float32, h::Float32) = begin
  u = cross(n, up)
  v = cross(u, n)
  p1 = p + w*u
  p3 = p - w*u
  p2 = p + h*v
  p4 = p - h*v
  StaticMesh(Pose(p), GLQuadMesh(p1, p2, p3, p4))
end

draw!(mesh::StaticMesh, shader::Shader) = begin
  M = model_matrix(mesh.pose)
  glUniformMatrix4fv(glGetUniformLocation(shader, "model"), 1, GL_FALSE, M)
  draw!(mesh.mesh)
end

draw!(cc::Plane, shader::Shader) = begin
  h = cell_mm(the_scan) / 2f0
  l =  h * sqrt(2f0)
  u = Ez
  v = cross(u, cc.n)
  mesh = GLQuadMesh(
    cc.p - l*v - h*u,
    cc.p + l*v - h*u,
    cc.p + l*v + h*u,
    cc.p - l*v + h*u,
  )
  M = scaling(1f0)
  glUniformMatrix4fv(glGetUniformLocation(shader, "model"), 1, GL_FALSE, M)
  draw!(mesh)
end

draw!(gs::GridSheet, shader::Shader) = begin
  M = scaling(1f0)
  glUniformMatrix4fv(glGetUniformLocation(shader, "model"), 1, GL_FALSE, M)
  draw!(GLGridMesh(gs))
end
