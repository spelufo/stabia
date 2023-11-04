stabia_dir(scan::HerculaneumScan) =
  joinpath(DATA_DIR, scan.volpkg_path, "stabia")

stabia_cell_dir(scan::HerculaneumScan, jy::Int, jx::Int, jz::Int) =
  joinpath(stabia_dir(scan), cell_name(jy, jx, jz))

# Perps

struct PerpsSaved
  guides :: Vector{Perp}
  walk :: Matrix{Float32}
  slices_dt :: Float32
  slices :: Array{Gray{Float32}, 3}
  flow :: Array{Vec2f, 3}
end

JLD2.writeas(::Type{Perps}) = PerpsSaved

Base.convert(::Type{PerpsSaved}, perps::Perps) =
  PerpsSaved(perps.guides, perps.walk, perps.slices_dt, perps.slices, perps.flow)

Base.convert(::Type{Perps}, ps::PerpsSaved) =
  Perps(
    :editing,
    ps.guides,
    GLMesh[],
    nothing,
    nothing,
    ps.walk,
    nothing,
    nothing,
    0f0,
    0f0,
    ps.slices_dt,
    ps.slices,
    ps.flow,
  )

stabia_cell_perps_path(scan::HerculaneumScan, jy::Int, jx::Int, jz::Int) =
  joinpath(stabia_cell_dir(scan, jy, jx, jz), "perps.jld2")

have_stabia_cell_perps(scan::HerculaneumScan, jy::Int, jx::Int, jz::Int) =
  isfile(stabia_cell_perps_path(scan, jy, jx, jz))

load_stabia_cell_perps(scan::HerculaneumScan, jy::Int, jx::Int, jz::Int) =
  load(stabia_cell_perps_path(scan, jy, jx, jz), "perps")

save_stabia_cell_perps(scan::HerculaneumScan, jy::Int, jx::Int, jz::Int, perps::Perps) =
  save(stabia_cell_perps_path(scan, jy, jx, jz), "perps", perps)
