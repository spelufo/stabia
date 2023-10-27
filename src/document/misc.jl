
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
  M = scaling(1f0)
  glUniformMatrix4fv(glGetUniformLocation(shader, "model"), 1, GL_FALSE, M)
  draw(mesh)
end
