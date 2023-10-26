
load_textures(cell::Cell) = begin
  if cell.texture > 0
    println("WARNING: load_textures recreating cell_texture")
    glDeleteTextures(1, Ref(cell.texture))
  end
  id = Ref(UInt32(0))
  glGenTextures(1, id)
  cell.texture = id[]
  glBindTexture(GL_TEXTURE_3D, cell.texture)
  glTexParameteri(GL_TEXTURE_3D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_BORDER)
  glTexParameteri(GL_TEXTURE_3D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_BORDER)
  glTexParameteri(GL_TEXTURE_3D, GL_TEXTURE_WRAP_R, GL_CLAMP_TO_BORDER)
  glTexParameteri(GL_TEXTURE_3D, GL_TEXTURE_MIN_FILTER, GL_NEAREST)
  glTexParameteri(GL_TEXTURE_3D, GL_TEXTURE_MAG_FILTER, GL_NEAREST)
  h, w, d = size(cell.V)
  glTexImage3D(GL_TEXTURE_3D, 0, GL_R16UI, h, w, d, 0, GL_RED_INTEGER, GL_UNSIGNED_SHORT, cell.V)
end

set_textures(cell::Cell, shader::Shader) = begin
  glActiveTexture(GL_TEXTURE1)
  glBindTexture(GL_TEXTURE_3D, cell.texture)
  scale = 1f0
  glUniform3f(glGetUniformLocation(shader, "CellScale"), scale, scale, scale)
  glUniform1i(glGetUniformLocation(shader, "Cell"), 1)
end

set_uniforms(cell::Cell, shader::Shader) = begin
  p0 = cell.p
  p1 = p0 + cell.L * E1
  glUniform3f(glGetUniformLocation(shader, "cellp0"), p0[1], p0[2], p0[3])
  glUniform3f(glGetUniformLocation(shader, "cellp1"), p1[1], p1[2], p1[3])
end
