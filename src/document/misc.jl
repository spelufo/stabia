
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
