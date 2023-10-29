# Follows Steger's paper and Ghassaei's virtual-unfolding.

const Vol = Array{Float32,3}

# using SpecialFunctions: erf
# ϕ(σ, x) = (sqrt(π/2) * (erf(x * σ)/sqrt(2) + 1)) / σ
g0(σ::Float32, x::Float32) = exp(-(x/σ)^2/2.0) / σ / sqrt(2π)
g1(σ::Float32, x::Float32) = -x * exp(-(x/σ)^2/2.0) / σ^3 / sqrt(2π)
g2(σ::Float32, x::Float32) = (x^2 - σ^2) * exp(-(x/σ)^2/2.0) / σ^5 / sqrt(2π)

steger_kernels(w::Float32) = begin
  σ = w/sqrt(12f0)
  MAX_SIZE_MASK_0 = 3.09023230616781f0  # Size for Gaussian mask.
  MAX_SIZE_MASK_1 = 3.46087178201605f0  # Size for 1st derivative mask.
  MAX_SIZE_MASK_2 = 3.82922419517181f0  # Size for 2nd derivative mask.
  dim = max(ceil(MAX_SIZE_MASK_0 * σ), ceil(MAX_SIZE_MASK_1 * σ), ceil(MAX_SIZE_MASK_2 * σ))
  G0 = Float32[g0(σ, Float32(x - dim)) for x in 0:2*dim]
  G1 = Float32[g1(σ, Float32(x - dim)) for x in 0:2*dim]
  G2 = Float32[g2(σ, Float32(x - dim)) for x in 0:2*dim]
  G0, G1, G2
end


# Do this in a function and save it so that we don't hold onto the result,
# because at  500M each we quickly run out of memory and the OS kills us.
build_derivative(V::Vol, k1::Vector{Float32}, k2::Vector{Float32}, k3::Vector{Float32}, path::String, name::String) = begin
  G = imfilter(V, kernelfactors((k1, k2, k3)))::Vol
  jldopen(path, "a+") do f
    f[name] = G
  end
end

build_cell_derivatives(scan::HerculaneumScan, jy::Int, jx::Int, jz::Int; thickness::Float32 = 15f0) = begin
  path = cell_derivatives_path(scan, jy, jx, jz)
  println("Loading cell...")
  @time V = convert(Vol, load_cell(scan, jy, jx, jz))
  println("Building steger kernels...")
  @time G0, G1, G2 = steger_kernels(thickness)
  println("Building first derivatives...")
  @time build_derivative(V, G1, G0, G0, path, "GY")
  @time build_derivative(V, G0, G1, G0, path, "GX")
  @time build_derivative(V, G0, G0, G1, path, "GZ")
  GC.gc()
  println("Building second derivatives...")
  @time build_derivative(V, G0, G1, G1, path, "GZX")
  @time build_derivative(V, G1, G0, G1, path, "GYZ")
  @time build_derivative(V, G1, G1, G0, path, "GXY")
  GC.gc()
  @time build_derivative(V, G2, G0, G0, path, "GYY")
  @time build_derivative(V, G0, G2, G0, path, "GXX")
  @time build_derivative(V, G0, G0, G2, path, "GZZ")
  GC.gc()
  jldopen(path, "a+") do f
    f["thickness"] = thickness
  end
  println("Done.")
end

# julia> build_cell_derivatives(scroll_1_54, 7, 7, 14)
# Loading cell...
#   1.615908 seconds (66.41 k allocations: 1.168 GiB, 2.61% gc time, 2.97% compilation time)
# Building steger kernels...
# Building first derivatives...
#  14.030557 seconds (234.53 k allocations: 2.627 GiB, 0.08% gc time, 0.89% compilation time)
#  11.938562 seconds (166 allocations: 2.613 GiB, 0.37% gc time)
#  11.966965 seconds (162 allocations: 2.613 GiB, 0.17% gc time)
# Building second derivatives...
#  11.598430 seconds (164 allocations: 2.613 GiB, 0.01% gc time)
#  11.965154 seconds (167 allocations: 2.613 GiB, 0.16% gc time)
#  12.092336 seconds (168 allocations: 2.613 GiB, 0.17% gc time)
#  11.778744 seconds (170 allocations: 2.613 GiB, 0.01% gc time)
#  11.842674 seconds (172 allocations: 2.613 GiB, 0.16% gc time)
#  12.114151 seconds (174 allocations: 2.613 GiB, 0.17% gc time)
# Done.

build_normals_steger(GXX::Vol, GYY::Vol, GZZ::Vol, GXY::Vol, GYZ::Vol, GZX::Vol) = begin
  N = Array{Float32, 4}(undef, (3, 500, 500, 500))  # 1.5G
  r = Array{Float32, 3}(undef, (500, 500, 500))
  Threads.@threads for z = 1:500
    H = zeros(Float32, 3, 3)
    for x = 1:500, y = 1:500
      H[1,1] = GXX[y, x, z]
      H[2,2] = GYY[y, x, z]
      H[3,3] = GZZ[y, x, z]
      H[1,2] = H[2,1] = GXY[y, x, z]
      H[2,3] = H[3,2] = GYZ[y, x, z]
      H[3,1] = H[1,3] = GZX[y, x, z]
      e = eigen(H)
      i = argmax(e.values)
      N[:, y, x, z] = e.vectors[:, i]
      r[y, x, z] = e.values[i]
    end
  end
  (N, r)
end

build_cell_normals_steger(scan::HerculaneumScan, jy::Int, jx::Int, jz::Int) = begin
  println("Loading cell...")
  @time V = convert(Vol, load_cell(scan, jy, jx, jz))
  println("Loading cell derivatives...")
  @assert have_cell_derivatives(scan, jy, jx, jz) "Cell derivatives not found. Run build_cell_derivatives first."
  @time GXX, GYY, GZZ, GXY, GYZ, GZX = load_cell_derivatives(
    scan, jy, jx, jz, ("GXX", "GYY", "GZZ", "GXY", "GYZ", "GZX"))
  println("Building cell normals...")
  @time N, r = build_normals_steger(GXX, GYY, GZZ, GXY, GYZ, GZX)
  println("Saving cell normals...")
  @time save_cell_normals_steger(scan, jy, jx, jz, N, r)
  println("Done.")
  nothing
end

# julia> build_cell_normals_steger(scroll_1_54, 7, 7, 14)
# Loading cell...
#   1.331782 seconds (2.21 k allocations: 1.164 GiB, 1.90% gc time)
# Loading cell derivatives...
#   1.238585 seconds (120.07 k allocations: 2.802 GiB, 1.51% gc time, 7.50% compilation time)
# Building cell normals...
# 159.981267 seconds (1.50 G allocations: 177.049 GiB, 19.82% gc time, 8.93% compilation time)
# Saving cell normals...
#   3.041628 seconds (826.49 k allocations: 57.629 MiB, 0.47% gc time, 10.19% compilation time)
# Done.


# 3. Relaxed normals ###########################################################

build_normals_relaxed_step(
  N::Array{Float32, 4}, r::Array{Float32, 3}, Nr::Array{Float32, 4}, rr::Array{Float32, 3},
  GXX::Vol, GYY::Vol, GZZ::Vol, GXY::Vol, GYZ::Vol, GZX::Vol
) = begin
  Threads.@threads for z = 2:499
    @inbounds for x = 2:499
      @simd for y = 2:499
        # Write it out, to avoid allocation...
        Nc  = SVector{3,Float32}(N[1, y, x, z],   N[2, y, x, z],   N[3, y, x, z]);   rc  = abs(r[y, x, z])
        Nyp = SVector{3,Float32}(N[1, y+1, x, z], N[2, y+1, x, z], N[3, y+1, x, z]); ryp = abs(r[y+1, x, z])
        Nyn = SVector{3,Float32}(N[1, y-1, x, z], N[2, y-1, x, z], N[3, y-1, x, z]); ryn = abs(r[y-1, x, z])
        Nxp = SVector{3,Float32}(N[1, y, x+1, z], N[2, y, x+1, z], N[3, y, x+1, z]); rxp = abs(r[y, x+1, z])
        Nxn = SVector{3,Float32}(N[1, y, x-1, z], N[2, y, x-1, z], N[3, y, x-1, z]); rxn = abs(r[y, x-1, z])
        Nzp = SVector{3,Float32}(N[1, y, x, z+1], N[2, y, x, z+1], N[3, y, x, z+1]); rzp = abs(r[y, x, z+1])
        Nzn = SVector{3,Float32}(N[1, y, x, z-1], N[2, y, x, z-1], N[3, y, x, z-1]); rzn = abs(r[y, x, z-1])

        Navg = normalize(rc*Nc + ryp*Nyp + ryn*Nyn + rxp*Nxp + rxn*Nxn + rzp*Nzp + rzn*Nzn)
        Nr[:, y, x, z] = Navg
        rr[y, x, z] = GXX[y,x,z]*Navg[1]^2 + GYY[y,x,z]*Navg[2]^2 + GZZ[y,x,z]*Navg[3]^2 +
          2.0f0 * (GXY[y,x,z]*Navg[1]*Navg[2] + GYZ[y,x,z]*Navg[2]*Navg[3] + GZX[y,x,z]*Navg[3]*Navg[1])
      end
    end
  end
  nothing
end

build_normals_relaxed(N::Array{Float32,4}, r::Array{Float32,3}, GXX::Vol, GYY::Vol, GZZ::Vol, GXY::Vol, GYZ::Vol, GZX::Vol) = begin
  Nr::Array{Float32,4} = Array{Float32,4}(undef, size(N))
  rr::Array{Float32,3} = Array{Float32,3}(undef, size(r))
  iters = 40
  for i = 1:iters
    build_normals_relaxed_step(N, r, Nr, rr, GXX, GYY, GZZ, GXY, GYZ, GZX)
    N, Nr = Nr, N
  end
  Nr, rr
end

build_cell_normals_relaxed(scan::HerculaneumScan, jy::Int, jx::Int, jz::Int) = begin
  println("Loading cell derivatives...")
  @assert have_cell_derivatives(scan, jy, jx, jz) "Cell derivatives not found. Run build_cell_derivatives first."
  @time GXX, GYY, GZZ, GXY, GYZ, GZX = load_cell_derivatives(
    scan, jy, jx, jz, ("GXX", "GYY", "GZZ", "GXY", "GYZ", "GZX"))
  println("Loading cell normals...")
  @time N, r = load_cell_normals_steger(scan, jy, jx, jz)
  println("Building relaxed normals...")
  @time Nr, rr = build_normals_relaxed(N, r, GXX, GYY, GZZ, GXY, GYZ, GZX)
  println("Saving relaxed normals...")
  @time save_cell_normals_relaxed(scan, jy, jx, jz, Nr, rr)
  println("Done.")
end

# julia> build_cell_normals_relaxed(scroll_1_54, 7,7,14)
# Loading cell derivatives...
#   0.742260 seconds (436.66 k allocations: 2.819 GiB, 5.36% gc time, 32.50% compilation time)
# Loading cell normals...
#   0.348383 seconds (14.82 k allocations: 1.864 GiB, 2.35% gc time, 9.03% compilation time)
# Building relaxed normals...
#  29.697322 seconds (201.15 k allocations: 1.876 GiB, 0.02% gc time, 7.22% compilation time)
# Saving relaxed normals...
#   3.475008 seconds (1.83 M allocations: 125.639 MiB, 0.87% gc time, 18.00% compilation time)
# Done.

