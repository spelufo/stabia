
mutable struct GridSheet <: DocumentObject
  points :: Matrix{Vec3f}
  coords :: Matrix{Vec2f}
end

GridSheet(o::Vec3f, u::Vec3f, v::Vec3f, l::Float32, ny::Int, nx::Int; o2::Vec2f = Vec2f(0f0, 0f0)) = begin
  points = Matrix{Vec3f}(undef, ny, nx)
  coords = Matrix{Vec2f}(undef, ny, nx)
  for ix = 1:nx, iy = 1:ny
    x = l*(ix-1)
    y = l*(iy-1)
    points[iy, ix] = o + x*u + y*v
    coords[iy, ix] = o2 + Vec2f(x, y)
  end
  GridSheet(points, coords)
end

GridSheetFromRange(o::Vec3f, p1::Vec3f, up::Vec3f, l::Float32; o2::Vec2f = Vec2f(0f0, 0f0)) = begin
  v = normalize(up)
  diag = p1 - o
  n = normalize(cross(diag, v))
  u = cross(v, n)
  nx_1 = ceil(Int, abs(dot(diag, u))/l)
  ny_1 = ceil(Int, abs(dot(diag, v))/l)
  GridSheet(o, u, v, l, ny_1+1, nx_1+1)
end

GridSheetFromCenter(c::Vec3f, n::Vec3f, v::Vec3f, l::Float32, ny::Int, nx::Int; o2::Vec2f = Vec2f(0f0, 0f0)) = begin
  u = cross(v, n)
  hx, hy = 0.5f0*(nx-1)*l, 0.5f0*(ny-1)*l
  o = c - hx*u - hy*v
  GridSheet(o, u, v, l, ny, nx; o2 = o2 - Vec2f(hx, hy))
end

@inline neighbors(s::GridSheet, i::Tuple{Int, Int}) = begin
  iy, ix = i
  neighs = []
  iy - 1 > 0                 && push!(neighs, (iy-1, ix))
  iy + 1 < size(s.points, 1) && push!(neighs, (iy+1, ix))
  ix - 1 > 0                 && push!(neighs, (iy, ix-1))
  ix + 1 < size(s.points, 2) && push!(neighs, (iy, ix+1))
  neighs
end

# const MAX_NEIGHS = 6
# mutable struct Sheet
#   points :: Vector{Vec3f}
#   coords :: Vector{Vec2f}
#   neighs :: Vector{Int32}
# end



draw(gs::GridSheet, shader::Shader) = begin
  M = scaling(1f0)
  glUniformMatrix4fv(glGetUniformLocation(shader, "model"), 1, GL_FALSE, M)
  draw(GLGridMesh(gs))
end


GLGridMesh(g::GridSheet) = begin
  vertices = reinterpret(GLVertex, vec(g.points))
  ny, nx = size(g.points)
  indices = Array{UInt32, 1}(undef, 2*3*(ny-1)*(nx-1))
  for ix = 0:nx-2
    for iy = 0:ny-2
      id = ix*ny + iy
      indices[6*(iy + ix*(ny-1)) + 1] = id
      indices[6*(iy + ix*(ny-1)) + 2] = id + nx
      indices[6*(iy + ix*(ny-1)) + 3] = id + nx + 1
      indices[6*(iy + ix*(ny-1)) + 4] = id
      indices[6*(iy + ix*(ny-1)) + 5] = id + nx + 1
      indices[6*(iy + ix*(ny-1)) + 6] = id + 1
    end
  end
  mesh = GLMesh(vertices, indices, 0, 0, 0)
  to_gpu!(mesh)
  mesh
end

