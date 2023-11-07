# TODO, issues:
#
# - The rasterization has problems, there are artifacts. It being a little off
#   shouldn't hurt us but these big lines where there should be none are an issue.
#   I think it should be the code but I guess it could be the meshes too.
#
# - Computing it SDF style for each pixel might be better. Can change the
#   thickness and it won't leave holes. Also, the triangles are from MC which
#   makes them small, so O(l^3) per triangle might not be so bad.
#
# - If constraining relaxation to the probabilities mask I got the impresion that
#   one side of the sheets lies outside the section classified as sheet so its
#   potential doesn't propagate. Use dilate on S, or P, or both, to get them to
#   overlap. Dilate on S makes sense even without this issue, sounds desirable.
#
# - The outer boundary needs some special handling, otherwise it is a ϕ = 0 that
#   leaks into the rest of the volume through relaxation. We would like to fill
#   the cell with the nearest sheet potential instead. Maybe do a prepass around
#   the boundary extending the non zero values from S to the border. We'll also
#   need to run relaxation on the boundary, which I elided to simplify things.
#
# - Mesh the result with marching squares and see how it does in blender.



rasterize_line!(V::AbstractArray{Float32, 2}, a::Vec2f, b::Vec2f, value::Float32) = begin
  # Bresenham's... Let's hope chatgpt gets it right.
  x0, y0 = Int(round(a[1])), Int(round(a[2]))
  x1, y1 = Int(round(b[1])), Int(round(b[2]))
  dx = abs(x1 - x0)
  dy = -abs(y1 - y0)
  sx = x0 < x1 ? 1 : -1
  sy = y0 < y1 ? 1 : -1
  err = dx + dy  # error value
  while true
    if x0 >= 1 && y0 >= 1 && x0 <= size(V, 2) && y0 <= size(V, 1)
      V[y0, x0] = value
    end
    if x0 == x1 && y0 == y1
      break
    end
    e2 = 2 * err
    if e2 >= dy  # e_xy+e_x > 0
      err += dy
      x0 += sx
    end
    if e2 <= dx  # e_xy+e_y < 0
      err += dx
      y0 += sy
    end
  end
  nothing
end

rasterize_triangle!(V::Array{Float32, 3}, v1, v2, v3, value) = begin
  # TODO: The right thing would be to clip. But we should be in bounds for our
  # current use case.
  if !all(0f0 .<= v1 .<= size(V)) return end
  if !all(0f0 .<= v2 .<= size(V)) return end
  if !all(0f0 .<= v3 .<= size(V)) return end

  # Bubble sort by z, so that v1[3] <= v2[3] <= v3[3].
  if v3[3] < v2[3]  v2, v3 = v3, v2  end
  if v2[3] < v1[3]  v1, v2 = v2, v1  end
  if v3[3] < v2[3]  v2, v3 = v3, v2  end

  a = b = Vec2f(v1[1], v1[2])
  if v3[3] == v1[3]  # All three on the same Z.
    @warn "rasterize_triangle! all z case (not implemented), skipping."
    # rasterize_triangle!(@view V[:,:,iz], v1[1:2], v2[1:2], v3[1:2])
    return
  end
  db = (Vec2f(v3[1], v3[2]) - b) / (v3[3] - v1[3])
  if v1[3] < v2[3]
    da = (Vec2f(v2[1], v2[2]) - a) / (v2[3] - v1[3])
    for iz = round(Int, v1[3]):round(Int, v2[3])
      rasterize_line!((@view V[:,:,iz]), a, b, value)
      a += da
      b += db
    end
  end
  if v2[3] < v3[3]
    a = Vec2f(v2[1], v2[2])
    da = (Vec2f(v3[1], v3[2]) - a) / (v3[3] - v2[3])
    for iz = round(Int, v2[3]):round(Int, v3[3])
      rasterize_line!((@view V[:,:,iz]), a, b, value)
      a += da
      b += db
    end
  end
  nothing
end

rasterize_mesh!(V::Array{Float32, 3}, mesh::GeometryBasics.Mesh, value::Float32, jy::Int, jx::Int, jz::Int) = begin
  origin = CELL_SIZE * Point3f(jx-1, jy-1, jz-1)
  points = reinterpret(Vec3f, metafree(coordinates(mesh)) .- origin)
  for (i1, i2, i3) = faces(mesh)
    rasterize_triangle!(V, points[i1], points[i2], points[i3], value)
  end
  nothing
end


potential_from_filename(filename::String) = begin
  m = match(r"s(\d\d)\.([ab])\.stl", filename)
  sheet_number = parse(Float32, m.captures[1])
  a_or_b = m.captures[2]
  2f0 * sheet_number + (if a_or_b == "a" 0 else 1 end) - 1f0
end


init_potential(scan::HerculaneumScan, jy::Int, jx::Int, jz::Int) = begin
  S = zeros(Float32, CELL_SIZE, CELL_SIZE, CELL_SIZE)
  for (filename, mesh) = load_cell_labels(scan, jy, jx, jz)
    ϕ = potential_from_filename(filename)
    rasterize_mesh!(S, mesh, ϕ, jy, jx, jz)
  end
  S
end

relax_potential_step!(ϕ::Array{Float32, 3}, S::Array{Float32, 3}, P::Array{Float32, 3}) = begin
  Threads.@threads for iz = 2:CELL_SIZE-1
    @inbounds for ix = 2:CELL_SIZE-1, iy = 2:CELL_SIZE-1
      if S[iy, ix, iz] > 0.0f0 # || P[iy, ix, iz] < 0.5f0
        continue
      end
      v = 0f0
      v += ϕ[iy, ix, iz]
      v += ϕ[iy-1, ix, iz]
      v += ϕ[iy+1, ix, iz]
      v += ϕ[iy, ix-1, iz]
      v += ϕ[iy, ix+1, iz]
      v += ϕ[iy, ix, iz-1]
      v += ϕ[iy, ix, iz+1]
      ϕ[iy, ix, iz] = v / 7f0
    end
  end
end

relax_potential(scan::HerculaneumScan, jy::Int, jx::Int, jz::Int) = begin
  P = load_cell_probabilities(scan, jy, jx, jz)
  S = init_potential(scan, jy, jx, jz)
  ϕ = copy(S)
  for i = 1:2000 # 269.346500 seconds (165.78 k allocations: 14.488 MiB, 0.11% compilation time)
    relax_potential_step!(ϕ, S, P)
  end
  ϕ
end
