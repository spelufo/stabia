
mutable struct GLLine
  vertices :: Vector{GLVertex}
  gl_vb :: UInt32
  gl_va :: UInt32
end

GLLine(points::Vector{Vec3f}) = begin
  line = GLLine(reinterpret(GLVertex, points), 0, 0)
  to_gpu!(line)
  line
end

to_gpu!(line::GLLine) = begin
  # Init box vertex array.
  id = Ref(UInt32(0))
  glGenVertexArrays(1, id)
  line.gl_va = id[]
  glBindVertexArray(line.gl_va)

  # GLVertex buffer.
  id = Ref(UInt32(0))
  glGenBuffers(1, id)
  line.gl_vb = id[]
  glBindBuffer(GL_ARRAY_BUFFER, line.gl_vb)
  glBufferData(GL_ARRAY_BUFFER, sizeof(line.vertices), line.vertices, GL_DYNAMIC_DRAW)

  # GLVertex attributes.
  glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, sizeof(GLVertex), C_NULL)
  glEnableVertexAttribArray(0)

  # Unbinding so code after this does not depend on previously bound objects.
  glBindBuffer(GL_ARRAY_BUFFER, 0)
  glBindVertexArray(0)
end

draw(line::GLLine) = begin
  glBindVertexArray(line.gl_va)
  glDrawArrays(GL_LINE_STRIP, 0, length(line.vertices))
end

draw(line::GLLine, shader::Shader) = begin
  M = scaling(1f0)
  glUniformMatrix4fv(glGetUniformLocation(shader, "model"), 1, GL_FALSE, M)
  draw(line)
end
