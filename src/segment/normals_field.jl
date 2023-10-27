using FFTW

estimate_normal(v::AbstractArray{Float32, 3}, radius_dir::Vec3f) = begin
  l = size(v, 1)
  c = div(l, 2) + 1
  r0 = div(l, 4) + 1
  f = norm.(fftshift(fft(v)))
  f[c, c, c] = 0f0

  M = 0f0
  N = zero(Vec3f)
  δ = atan(1/c)
  for θ = 0:δ:π, ϕ = 0:δ:π
    m = 0f0
    for r = r0:c-1
      x = round(Int, r*sin(ϕ)*cos(θ))
      y = round(Int, r*sin(ϕ)*sin(θ))
      z = round(Int, r*cos(ϕ))
      m += f[c + y, c + x, c + z]
    end
    if m > M
      M = m
      N = m.*Vec3f(sin(ϕ)*cos(θ), sin(ϕ)*sin(θ), cos(ϕ))./c
    end
  end
  if dot(N, radius_dir) < 0
    N = -N
  end
  N
end

estimate_normals(V::Array{Float32, 3}, radius_dir::Vec3f; l=10) = begin
  ly, lx, lz = size(V)
  N = zeros(Vec3f, div.(size(V), l))
  w = div(l, 2)
  r = w:l:lz-w
  Threads.@threads for iz = 1:length(r)
    cz = r[iz]
    for (ix, cx) = enumerate(w:l:lx-w),
        (iy, cy) = enumerate(w:l:ly-w)
      v = @view V[cy-w+1:cy+w-1, cx-w+1:cx+w-1, cz-w+1:cz+w-1]
      N[iy, ix, iz] = estimate_normal(v, radius_dir)
    end
  end
  N
end

estimate_normals_points(ls::Ints3; l=10, PType=Vec3f) = begin
  ly, lx, lz = ls
  P = zeros(PType, div.(ls, l))
  w = div(l, 2)
  for (iz, cz) = enumerate(w:l:lz-w),
      (ix, cx) = enumerate(w:l:lx-w),
      (iy, cy) = enumerate(w:l:ly-w)
    P[iy, ix, iz] = PType(cx, cy, cz)
  end
  P
end

compute_cell_normals(scan::HerculaneumScan, jy::Int, jx::Int, jz::Int) = begin
  if have_cell_normals(scan, jy, jx, jz)
    println("Cell normals were already computed. Delete the file to recompute.")
    println("path: ", cell_normals_path(scan, jy, jx, jz))
    return nothing
  end
  radius_dir = scroll_radius_dir(scan, jy, jx, jz)
  println("Loading cell...")
  @time V = load_cell(scan, jy, jx, jz)
  println("Computing normals...")
  @time N = estimate_normals(Float32.(V), radius_dir)
  P = estimate_normals_points(size(V))
  println("Saving normals...")
  @time save_cell_normals(scan, jy, jx, jz, N, P)
  nothing
end

normal_equipotential_mesh_init(scan::HerculaneumScan, j::Ints3, N::Array{Vec3f, 3}, p0::Vec3f) = begin
  m = size(N, 1)
  l = div(CELL_SIZE, m)
  @assert l == 10 "Expected l to be 10, the default value estimate_normals uses."
  o = cell_position_mm(scan, j...)
  L = cell_mm(scan)
  @inline world_to_voxels(p::Vec3f) = CELL_SIZE * (p - o) / L
  @inline voxels_to_nunit(p::Vec3f) = (p - Vec3f(l,l,l)./2f0) ./ l
  @inline map_p(p::Vec3f) = voxels_to_nunit(world_to_voxels(p))
  @inline eval_normal(p::Vec3f) = interpolate_trilinear(N, map_p(p))
  @inline in_bounds(p::Vec3f) = all(0.5f0 .< map_p(p) .< m-0.5f0)
  @assert in_bounds(p0) "p0 not in bounds"
  n = normalize(eval_normal(p0))
  u = cross(Ez, n)
  v = cross(n, u)
  k = 49 # must be odd
  s = GridSheetFromCenter(p0, n, v, 0.85f0*cell_mm(scan)/k, k, k)
  normal_equipotential_mesh_step!(δ::Float32, k_s::Float32, k_n::Float32, n_iters::Int) = begin
    do_point(iy::Int, ix::Int) = begin
      p = s.points[iy, ix]
      F = Vec3f(0f0)
      for (jy, jx) = neighbors(s, (iy, ix))
        q = s.points[jy, jx]
        # F += k_s * (q - p)
        if in_bounds(q)
          n = normalize(eval_normal(q))
          F += k_n * dot(n, (q - p)) * n
        end
      end
      s.points[iy, ix] += δ * F
    end
    for iter = 1:n_iters
      # These weird indexing is to run it in the order from the center out.
      # Maybe more trouble that what it's worth. We could run in any order
      # if the step is small enough.
      ko = div(k, 2) + 1
      for r = 1:ko-1
        for ix = ko-r:ko+r, iy = (ko-r, ko+r)
          do_point(iy, ix)
        end
        for iy = ko-r:ko+r, ix = (ko-r, ko+r)
          do_point(iy, ix)
        end
      end
    end
    nothing
  end
  # Returning the step closure is a bit of a hack. Is it a problem?
  s, normal_equipotential_mesh_step!
end



# TODO: I changed the grid that estimate_normal uses. This is probably off.
# Fix it. Not very important because it isn't currently in use.
# trace_normal(p0::Vec3f, M::Array{Float32, 3}, N::Array{Vec3f, 3}) = begin
#   w = div(500, size(N, 1) + 2)
#   eval_mask(p::Vec3f) = interpolate_trilinear(M, p)
#   eval_normal(p::Vec3f) = interpolate_trilinear(N, (p .- w) ./ w)
#   in_bounds(p::Vec3f) = all(w .< p .< (500f0 - w))
#   threshold = 0.5
#   δ = 1f0
#   p = p0
#   n = eval_normal(p)
#   in_papyrus = eval_mask(p) > threshold
#   started_in_papyrus = in_papyrus
#   hits = Vec3f[]
#   while in_bounds(p)
#     v = eval_mask(p)
#     was_in_papyrus = in_papyrus
#     in_papyrus = v > threshold
#     if !was_in_papyrus && in_papyrus  # pierce into
#       push!(hits, p)
#     elseif was_in_papyrus && !in_papyrus  # pierce out of
#       push!(hits, p)
#     end
#     p += δ*n
#   end
#   hits
# end

