

struct GLVertex
  p :: Vec3f
end

mutable struct GLMesh
  vertices :: Vector{GLVertex}
  indices :: Vector{UInt32}
  gl_vb :: UInt32
  gl_vi :: UInt32
  gl_va :: UInt32
end

to_gpu!(mesh::GLMesh) = begin
  # Init box vertex array.
  id = Ref(UInt32(0))
  glGenVertexArrays(1, id)
  mesh.gl_va = id[]
  glBindVertexArray(mesh.gl_va)

  # GLVertex buffer.
  id = Ref(UInt32(0))
  glGenBuffers(1, id)
  mesh.gl_vb = id[]
  glBindBuffer(GL_ARRAY_BUFFER, mesh.gl_vb)
  glBufferData(GL_ARRAY_BUFFER, sizeof(mesh.vertices), mesh.vertices, GL_STATIC_DRAW)

  # GLVertex attributes.
  glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, sizeof(GLVertex), C_NULL)
  glEnableVertexAttribArray(0)
  glVertexAttribPointer(1, 3, GL_FLOAT, GL_FALSE, sizeof(GLVertex), C_NULL + 3*sizeof(Float32))
  glEnableVertexAttribArray(1)
  glVertexAttribPointer(2, 2, GL_FLOAT, GL_FALSE, sizeof(GLVertex), C_NULL + 6*sizeof(Float32))
  glEnableVertexAttribArray(2)

  # Indices buffer.
  id = Ref(UInt32(0))
  glGenBuffers(1, id)
  mesh.gl_vi = id[]
  glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, mesh.gl_vi)
  glBufferData(GL_ELEMENT_ARRAY_BUFFER, sizeof(mesh.indices), mesh.indices, GL_STATIC_DRAW)

  # Unbinding can be useful to validate that code happening after this does not
  # depend on previously bound objects.
  glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, 0)
  glBindBuffer(GL_ARRAY_BUFFER, 0)
  glBindVertexArray(0)
end

draw!(mesh::GLMesh) = begin
  glBindVertexArray(mesh.gl_va)
  glBindBuffer(GL_ARRAY_BUFFER, mesh.gl_vb)
  glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, mesh.gl_vi)
  glDrawElements(GL_TRIANGLES, length(mesh.indices), GL_UNSIGNED_INT, C_NULL)
end


## GLMesh builders

GLBoxMesh(p0::Vec3f, p1::Vec3f) = begin
  vertices = GLVertex[
    GLVertex(Vec3f(p0[1], p0[2], p0[3])),
    GLVertex(Vec3f(p1[1], p0[2], p0[3])),
    GLVertex(Vec3f(p1[1], p1[2], p0[3])),
    GLVertex(Vec3f(p0[1], p1[2], p0[3])),
    GLVertex(Vec3f(p0[1], p0[2], p1[3])),
    GLVertex(Vec3f(p1[1], p0[2], p1[3])),
    GLVertex(Vec3f(p1[1], p1[2], p1[3])),
    GLVertex(Vec3f(p0[1], p1[2], p1[3])),
  ]
  indices = UInt32[
    0, 1, 2, 0, 2, 3, # bottom
    4, 6, 5, 4, 7, 6, # top
    0, 4, 5, 0, 5, 1,
    3, 7, 4, 3, 4, 0,
    1, 6, 2, 1, 5, 6,
    2, 7, 3, 2, 6, 7,
  ]
  mesh = GLMesh(vertices, indices, 0, 0, 0)
  to_gpu!(mesh)
  mesh
end


GLQuadMesh(p1::Vec3f, p2::Vec3f, p3::Vec3f, p4::Vec3f) = begin
  vertices = GLVertex[
    GLVertex(p1),
    GLVertex(p2),
    GLVertex(p3),
    GLVertex(p4),
  ]
  indices = UInt32[0, 1, 2, 0, 2, 3]
  mesh = GLMesh(vertices, indices, 0, 0, 0)
  to_gpu!(mesh)
  mesh
end
