
mutable struct StaticMesh
  pose :: Pose
  mesh :: GLMesh
end

StaticBoxMesh(p0::Vec3f, p1::Vec3f) =
  StaticMesh(Pose(p0), GLBoxMesh(zero(Vec3f), p1 - p0))
  # StaticMesh(Pose(E0), GLBoxMesh(p0, p1))

StaticQuadMesh(p::Vec3f, n::Vec3f, v::Vec3f, w::Float32, h::Float32) = begin
  h /= 2f0
  w /= 2f0
  u = cross(n, v)
  p1 = - w*u - h*v
  p2 = + w*u - h*v
  p3 = + w*u + h*v
  p4 = - w*u + h*v
  StaticMesh(Pose(p), GLQuadMesh(p1, p2, p3, p4))
end

draw(mesh::StaticMesh, shader::Shader) = begin
  M = model_matrix(mesh.pose)
  glUniformMatrix4fv(glGetUniformLocation(shader, "model"), 1, GL_FALSE, M)
  draw(mesh.mesh)
end

draw(cc::Plane, shader::Shader) = begin
  h = cell_mm(the_editor.scan) / 2f0
  l =  h * sqrt(2f0)
  u = Ez
  v = cross(u, cc.n)
  mesh = GLQuadMesh(
    cc.p - l*v - h*u,
    cc.p + l*v - h*u,
    cc.p + l*v + h*u,
    cc.p - l*v + h*u,
  )
  draw(mesh, shader)
end
