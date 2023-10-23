
load_textures(scanvol::ScanVolume) = begin
  if scanvol.small_texture <= 0
    id = Ref(UInt32(0))
    glGenTextures(1, id)
    scanvol.small_texture = id[]
  end
  glBindTexture(GL_TEXTURE_3D, scanvol.small_texture)
  glTexParameteri(GL_TEXTURE_3D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE)
  glTexParameteri(GL_TEXTURE_3D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE)
  glTexParameteri(GL_TEXTURE_3D, GL_TEXTURE_MIN_FILTER, GL_NEAREST)
  glTexParameteri(GL_TEXTURE_3D, GL_TEXTURE_MAG_FILTER, GL_NEAREST)
  h, w, d = size(scanvol.small)
  glTexImage3D(GL_TEXTURE_3D, 0, GL_R16UI, h, w, d, 0, GL_RED_INTEGER, GL_UNSIGNED_SHORT, scanvol.small)

  if scanvol.cell_texture <= 0
    id = Ref(UInt32(0))
    glGenTextures(1, id)
    scanvol.cell_texture = id[]
  end
  glBindTexture(GL_TEXTURE_3D, scanvol.cell_texture)
  glTexParameteri(GL_TEXTURE_3D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE)
  glTexParameteri(GL_TEXTURE_3D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE)
  glTexParameteri(GL_TEXTURE_3D, GL_TEXTURE_MIN_FILTER, GL_NEAREST)
  glTexParameteri(GL_TEXTURE_3D, GL_TEXTURE_MAG_FILTER, GL_NEAREST)
  h, w, d = size(scanvol.cell)
  glTexImage3D(GL_TEXTURE_3D, 0, GL_R16UI, h, w, d, 0, GL_RED_INTEGER, GL_UNSIGNED_SHORT, scanvol.cell)
end

set_textures(scanvol::ScanVolume, shader::Shader) = begin
  glActiveTexture(GL_TEXTURE0)
  glBindTexture(GL_TEXTURE_3D, scanvol.small_texture)

  glActiveTexture(GL_TEXTURE1)
  glBindTexture(GL_TEXTURE_3D, scanvol.cell_texture)

  glUniform3f(glGetUniformLocation(shader, "SmallScale"),
    (Float32.(scanvol.small_size./size(scanvol.small)))...)
  glUniform3f(glGetUniformLocation(shader, "CellScale"),
    (Float32.(scanvol.cell_size./size(scanvol.cell)))...)

  glUniform1i(glGetUniformLocation(shader, "Small"), 0)
  glUniform1i(glGetUniformLocation(shader, "Cell"), 1)
end


# GL uniforms.

set_uniforms(scanvol::ScanVolume, shader::Shader) = begin
  dims = dimensions(scanvol)
  glUniform3f(glGetUniformLocation(shader, "dimensions"), dims[1], dims[2], dims[3])
  p0, p1 = cell_position(scanvol)
  glUniform3f(glGetUniformLocation(shader, "cellp0"), p0[1], p0[2], p0[3])
  glUniform3f(glGetUniformLocation(shader, "cellp1"), p1[1], p1[2], p1[3])
end
