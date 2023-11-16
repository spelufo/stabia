rasterize_triangle!(V::Array{F, 3}, v1, v2, v3, value::F) where {F} = begin
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
    if abs(dot(w1, n)) < 1.5f0  # Within thickness from triangle plane.
      c1 = cross(e1, w1); c2 = cross(e2, w2); c3 = cross(e3, w3)
      if dot(c1, c2) > 0f0 && dot(c2, c3) > 0f0
        # All cross products in the same direction -> we're inside triangle.
        V[iy, ix, iz] = value
      end
    end
  end
  nothing
end

rasterize_mesh!(V::Array{F, 3}, mesh::GeometryBasics.Mesh, value::F, jy::Int, jx::Int, jz::Int) where {F} = begin
  origin = CELL_SIZE * Point3f(jx-1, jy-1, jz-1)
  points = reinterpret(Vec3f, metafree(coordinates(mesh)) .- origin)
  for (i1, i2, i3) = faces(mesh)
    rasterize_triangle!(V, points[i1], points[i2], points[i3], value)
  end
  nothing
end

rasterize_mesh_normals!(V::Array{Vec3f, 3}, mesh::GeometryBasics.Mesh, jy::Int, jx::Int, jz::Int, radius_dir::Vec3f) = begin
  origin = CELL_SIZE * Point3f(jx-1, jy-1, jz-1)
  points = reinterpret(Vec3f, metafree(coordinates(mesh)) .- origin)
  ns = normals(mesh)
  for (i1, i2, i3) = faces(mesh)
    n = normalize(ns[i1] + ns[i2] + ns[i3])
    # TODO: Skip rasterization of normals close to radius_dir perp.
    if dot(n, radius_dir) < 0f0
      n = -n
    end
    rasterize_triangle!(V, points[i1], points[i2], points[i3], n)
  end
  nothing
end

potential_from_filename(filename::String) = begin
  m = match(r"s(\d\d)\.([ab])\.stl", filename)
  sheet_number = parse(Float32, m.captures[1])
  a_or_b = m.captures[2]
  # For the a sides the potential is the sheet number. The b sides have the
  # same potential as the next sheet, which they might be touching.
  sheet_number + (if a_or_b == "b" 0.99f0 else 0f0 end)
end

init_potential(scan::HerculaneumScan, jy::Int, jx::Int, jz::Int) = begin
  S = zeros(Float32, CELL_SIZE, CELL_SIZE, CELL_SIZE)
  for (filename, mesh) = reverse(load_cell_labels(scan, jy, jx, jz))
    ϕ = potential_from_filename(filename)
    rasterize_mesh!(S, mesh, ϕ, jy, jx, jz)
  end
  dilate(S)
end

init_normals(scan::HerculaneumScan, jy::Int, jx::Int, jz::Int) = begin
  S = zeros(Vec3f, CELL_SIZE, CELL_SIZE, CELL_SIZE)
  radius_dir = scroll_radius_dir(scan, jy, jx, jz)
  N = fill(radius_dir, CELL_SIZE, CELL_SIZE, CELL_SIZE)
  for (filename, mesh) = reverse(load_cell_labels(scan, jy, jx, jz))
    rasterize_mesh_normals!(S, mesh, jy, jx, jz, radius_dir)
    rasterize_mesh_normals!(N, mesh, jy, jx, jz, radius_dir)
  end
  S, N
end

relax_potential_step!(ϕ::Array{Float32, 3}, S::Array{Float32, 3}, P::Array{Float32, 3}) = begin
  Threads.@threads for iz = 3:CELL_SIZE-2
    @inbounds for ix = 3:CELL_SIZE-2
      @simd for iy = 2:CELL_SIZE-1
        if S[iy, ix, iz] == 0f0
          s = 0f0; c = 0
          v = ϕ[iy  , ix, iz]; if v > 0f0  s += v; c += 1  end
          v = ϕ[iy-1, ix, iz]; if v > 0f0  s += v; c += 1  end
          v = ϕ[iy+1, ix, iz]; if v > 0f0  s += v; c += 1  end
          v = ϕ[iy, ix-1, iz]; if v > 0f0  s += v; c += 1  end
          v = ϕ[iy, ix+1, iz]; if v > 0f0  s += v; c += 1  end
          v = ϕ[iy, ix-2, iz]; if v > 0f0  s += v; c += 1  end
          v = ϕ[iy, ix+2, iz]; if v > 0f0  s += v; c += 1  end
          v = ϕ[iy, ix, iz-1]; if v > 0f0  s += v; c += 1  end
          v = ϕ[iy, ix, iz+1]; if v > 0f0  s += v; c += 1  end
          v = ϕ[iy, ix, iz-2]; if v > 0f0  s += v; c += 1  end
          v = ϕ[iy, ix, iz+2]; if v > 0f0  s += v; c += 1  end
          if c > 0
            ϕ[iy, ix, iz] = s / c
          end
        end
      end
    end
  end
end


relax_normals_step!(N::Array{Vec3f, 3}, S::Array{Vec3f, 3}, P::Array{Float32, 3}) = begin
  Threads.@threads for iz = 3:CELL_SIZE-2
    @inbounds for ix = 3:CELL_SIZE-2
      @simd for iy = 2:CELL_SIZE-1
        if S[iy, ix, iz] == Vec3f(0f0)
          s = Vec3f(0f0)
          s += N[iy  , ix, iz]
          s += N[iy-1, ix, iz]
          s += N[iy+1, ix, iz]
          s += N[iy, ix-1, iz]
          s += N[iy, ix+1, iz]
          s += N[iy, ix, iz-1]
          s += N[iy, ix, iz+1]
          N[iy, ix, iz] = s / 7f0
        end
      end
    end
  end
end

normalize_step!(N::Array{Vec3f, 3}, S::Array{Vec3f, 3}, P::Array{Float32, 3}) = begin
  Threads.@threads for iz = 3:CELL_SIZE-2
    @inbounds for ix = 3:CELL_SIZE-2
      @simd for iy = 2:CELL_SIZE-1
        N[iy, ix, iz] = normalize(N[iy, ix, iz])
      end
    end
  end
end


relax_potential_init(scan::HerculaneumScan, jy::Int, jx::Int, jz::Int) = begin
  P = load_cell_probabilities(scan, jy, jx, jz)
  S = init_potential(scan, jy, jx, jz)
  ϕ = copy(S)
  ϕ, S, P
end

relax_normals_init(scan::HerculaneumScan, jy::Int, jx::Int, jz::Int) = begin
  P = load_cell_probabilities(scan, jy, jx, jz)
  S, N = init_normals(scan, jy, jx, jz)
  N, S, P
end

relax_potential!(ϕ::Array{Float32, 3}, S::Array{Float32, 3}, P::Array{Float32, 3}, n_iters::Int = 1000) = begin
  for i = 1:n_iters relax_potential_step!(ϕ, S, P) end
  nothing
end

relax_normals!(N::Array{Vec3f, 3}, S::Array{Vec3f, 3}, P::Array{Float32, 3}, n_iters::Int = 200) = begin
  for i = 1:n_iters
    relax_normals_step!(N, S, P)
    if i % 20 == 0
      normalize_step!(N, S, P)
    end
  end
  normalize_step!(N, S, P)
  nothing
end

build_relax_potential(scan::HerculaneumScan, jy::Int, jx::Int, jz::Int) = begin
  ϕ, S, P = relax_potential_init(scan, jy, jx, jz)
  relax_potential!(ϕ, S, P)
  save_cell_potential(scan, jy, jx, jz, ϕ, S)
  ϕ, S, P
end

build_relax_normals(scan::HerculaneumScan, jy::Int, jx::Int, jz::Int) = begin
  N, S, P = relax_normals_init(scan, jy, jx, jz)
  relax_normals!(N, S, P)
  save_cell_normals_heat(scan, jy, jx, jz, N)
  N, S, P
end

vis_normals(N::Array{Vec3f}) = begin
  Nx = map(v -> v[1]/2f0 + 0.5f0, N)
  Ny = map(v -> v[2]/2f0 + 0.5f0, N)
  Nz = map(v -> v[3]/2f0 + 0.5f0, N)
  colorview(RGB, Nx, Ny, Nz)
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




# TODO: Use it or loose it.


relax_potential_2d_step!(ϕ, S, P) = begin
  Threads.@threads for ix = 2:CELL_SIZE-1
    @inbounds for iy = 2:CELL_SIZE-1
      if S[iy, ix] > 0.0f0 # || P[iy, ix] < 0.3f0
        continue
      end
      s = 0f0; c = 0
      v = ϕ[iy,   ix]; if v > 0f0  s += v; c += 1  end
      v = ϕ[iy-1, ix]; if v > 0f0  s += v; c += 1  end
      v = ϕ[iy+1, ix]; if v > 0f0  s += v; c += 1  end
      v = ϕ[iy, ix-1]; if v > 0f0  s += v; c += 1  end
      v = ϕ[iy, ix+1]; if v > 0f0  s += v; c += 1  end
      if c > 0
        ϕ[iy, ix] = s / c
      end
    end
  end
end


relax_potential_2d_boundary!(ϕ::Array{Float32, 3}, S::Array{Float32, 3}, P::Array{Float32, 3}, n_iters::Int = 1000) = begin
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
