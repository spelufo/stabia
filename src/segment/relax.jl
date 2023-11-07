# TODO, issues:
#
# - The outer boundary needs some special handling, otherwise it is a ϕ = 0 that
#   leaks into the rest of the volume through relaxation. We would like to fill
#   the cell with the nearest sheet potential instead. Maybe do a prepass around
#   the boundary extending the non zero values from S to the border. We'll also
#   need to run relaxation on the boundary, which I elided to simplify things.


rasterize_triangle!(V::Array{Float32, 3}, v1, v2, v3, value) = begin
  # TODO: Clipping. But we should be in bounds for our current use case.
  if !all(1 .<= v1 .<= size(V).-1) return end
  if !all(1 .<= v2 .<= size(V).-1) return end
  if !all(1 .<= v3 .<= size(V).-1) return end
  bbox_min = floor.(Int, min.(v1, v2, v3))
  bbox_max = ceil.(Int, max.(v1, v2, v3))
  e1 = v2 - v1;  e2 = v3 - v2;  e3 = v1 - v3
  n = normalize(cross(e1, -e3))
  @inbounds for iz = bbox_min[3]:bbox_max[3], ix = bbox_min[1]:bbox_max[1], iy = bbox_min[2]:bbox_max[2]
    p = Vec3f(ix + 0.5f0, iy + 0.5f0, iz + 0.5f0)
    w1 = v1 - p;  w2 = v2 - p;  w3 = v3 - p
    if abs(dot(w1, n)) < 3f0  # Within thickness from triangle plane.
      c1 = cross(e1, w1); c2 = cross(e2, w2); c3 = cross(e3, w3)
      if dot(c1, c2) > 0f0 && dot(c2, c3) > 0f0
        # All cross products in the same direction -> we're inside triangle.
        V[iy, ix, iz] = value
      end
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
  # For the a sides the potential is the sheet number. The b sides have the
  # same potential as the next sheet, which they might be touching.
  sheet_number + (if a_or_b == "b" 1 else 0 end)
end


init_potential(scan::HerculaneumScan, jy::Int, jx::Int, jz::Int) = begin
  S = zeros(Float32, CELL_SIZE, CELL_SIZE, CELL_SIZE)
  for (filename, mesh) = load_cell_labels(scan, jy, jx, jz)
    ϕ = potential_from_filename(filename)
    rasterize_mesh!(S, mesh, ϕ, jy, jx, jz)
  end
  dilate(S)
end

relax_potential_step!(ϕ::Array{Float32, 3}, S::Array{Float32, 3}, P::Array{Float32, 3}) = begin
  Threads.@threads for iz = 2:CELL_SIZE-1
    @inbounds for ix = 2:CELL_SIZE-1, iy = 2:CELL_SIZE-1
      # We could also skip voxels with `P[iy, ix, iz] < 0.5f0`, but I think
      # filling all the holes with potential should yield better results.
      if S[iy, ix, iz] > 0.0f0 || P[iy, ix, iz] < 0.3f0
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

relax_potential_2d_step!(ϕ, S, P) = begin
  Threads.@threads for ix = 2:CELL_SIZE-1
    @inbounds for iy = 2:CELL_SIZE-1
      if S[iy, ix] > 0.0f0 || P[iy, ix] < 0.3f0
        continue
      end
      v = 0f0
      v += ϕ[iy, ix]
      v += ϕ[iy-1, ix]
      v += ϕ[iy+1, ix]
      v += ϕ[iy, ix-1]
      v += ϕ[iy, ix+1]
      ϕ[iy, ix] = v / 5f0
    end
  end
end

relax_potential_init(scan::HerculaneumScan, jy::Int, jx::Int, jz::Int) = begin
  P = load_cell_probabilities(scan, jy, jx, jz)
  S = init_potential(scan, jy, jx, jz)
  ϕ = copy(S)
  ϕ, S, P
end

relax_potential!(ϕ::Array{Float32, 3}, S::Array{Float32, 3}, P::Array{Float32, 3}, n_iters::Int = 5000) = begin
  # When n_iters = 2000: 269.346500 seconds (165.78 k allocations: 14.488 MiB, 0.11% compilation time)
  for i = 1:n_iters
    relax_potential_step!(ϕ, S, P)
  end
  nothing
end

relax_potential_2d_boundary!(ϕ::Array{Float32, 3}, S::Array{Float32, 3}, P::Array{Float32, 3}, n_iters::Int = 5000) = begin
  ϕ_2d = @view ϕ[:,:,6]; S_2d = @view S[:,:,6] ; P_2d = @view P[:,:,6]
  for i = 1:n_iters  relax_potential_2d_step!(ϕ_2d, S_2d, P_2d)  end
  for iz = 1:6  S[:,:,iz] .= ϕ_2d  end

  ϕ_2d = @view ϕ[:,:,493]; S_2d = @view S[:,:,493] ; P_2d = @view P[:,:,493]
  for i = 1:n_iters  relax_potential_2d_step!(ϕ_2d, S_2d, P_2d)  end
  for iz = 493:500  S[:,:,iz] .= ϕ_2d  end

  ϕ_2d = @view ϕ[6,:,:]; S_2d = @view S[6,:,:] ; P_2d = @view P[6,:,:]
  for i = 1:n_iters  relax_potential_2d_step!(ϕ_2d, S_2d, P_2d)  end
  for iy = 1:6  S[iy,:,:] .= ϕ_2d  end

  ϕ_2d = @view ϕ[493,:,:]; S_2d = @view S[493,:,:] ; P_2d = @view P[493,:,:]
  for i = 1:n_iters  relax_potential_2d_step!(ϕ_2d, S_2d, P_2d)  end
  for iy = 493:500  S[iy,:,:] .= ϕ_2d  end

  ϕ_2d = @view ϕ[:,6,:]; S_2d = @view S[:,6,:] ; P_2d = @view P[:,6,:]
  for i = 1:n_iters  relax_potential_2d_step!(ϕ_2d, S_2d, P_2d)  end
  for ix = 1:6  S[:,ix,:] .= ϕ_2d  end

  ϕ_2d = @view ϕ[:,493,:]; S_2d = @view S[:,493,:] ; P_2d = @view P[:,493,:]
  for i = 1:n_iters  relax_potential_2d_step!(ϕ_2d, S_2d, P_2d)  end
  for ix = 493:500  S[:,ix,:] .= ϕ_2d  end

  nothing
end

build_relax_potential(scan::HerculaneumScan, jy::Int, jx::Int, jz::Int) = begin
  ϕ, S, P = relax_potential_init(scan, jy, jx, jz)
  relax_potential_2d_boundary!(ϕ, S, P)
  relax_potential!(ϕ, S, P)
  save_cell_potential(scan, jy, jx, jz, ϕ, S)
  ϕ, S, P
end


vis_distinguishable_colors(ϕ::Array{Float32, 3}, colors = distinguishable_colors(40)) = begin
  V = zeros(eltype(colors), size(ϕ))
  map!(V, ϕ) do v
    i = floor(Int, v)
    if 1 <= i <= length(colors)
      colors[i]
    else
      zero(eltype(colors))
    end
  end
  V, colors
end
