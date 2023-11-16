# Root

segmentation_dir(scan::HerculaneumScan) =
  joinpath(DATA_DIR, scan.volpkg_path, "segmentation")

cell_segmentation_dir(scan::HerculaneumScan, jy::Int, jx::Int, jz::Int) =
  joinpath(segmentation_dir(scan), cell_name(jy, jx, jz))


# Probabilities (Ilastik)

cell_probabilities_path(scan::HerculaneumScan, jy::Int, jx::Int, jz::Int) =
  joinpath(cell_segmentation_dir(scan, jy, jx, jz), "$(cell_name(jy, jx, jz))_probabilities.h5")

load_cell_probabilities(scan::HerculaneumScan, jy::Int, jx::Int, jz::Int) = begin
  fid = h5open(cell_probabilities_path(scan, jy, jx, jz))
  P = permutedims(read(fid, "exported_data")[1,:,:,:,1], (2, 1, 3))
  close(fid)
  P
end


# Holes

cell_hole_ids_path(scan::HerculaneumScan, jy::Int, jx::Int, jz::Int) =
  joinpath(cell_segmentation_dir(scan, jy, jx, jz), "$(cell_name(jy, jx, jz))_hole_ids.h5")

cell_holes_dir(scan::HerculaneumScan, jy::Int, jx::Int, jz::Int) =
  joinpath(cell_segmentation_dir(scan, jy, jx, jz), "holes")

have_cell_holes(scan::HerculaneumScan, jy::Int, jx::Int, jz::Int) =
  isdir(cell_holes_dir(scan, jy, jx, jz))

load_cell_holes(scan::HerculaneumScan, jy::Int, jx::Int, jz::Int) = begin
  holes = []
  holes_dir = cell_holes_dir(scroll_1_54, jy, jx, jz)
  for hole_filename = readdir(holes_dir)
    endswith(hole_filename, ".stl") || continue
    hole_path = joinpath(holes_dir, hole_filename)
    push!(holes, load(hole_path))
  end
  holes
end


# Labels

cell_labels_dir(scan::HerculaneumScan, jy::Int, jx::Int, jz::Int) =
  joinpath(cell_segmentation_dir(scan, jy, jx, jz), "labels")

have_cell_labels(scan::HerculaneumScan, jy::Int, jx::Int, jz::Int) =
  isdir(cell_labels_dir(scan, jy, jx, jz))

load_cell_labels(scan::HerculaneumScan, jy::Int, jx::Int, jz::Int) = begin
  labels = []
  labels_dir = cell_labels_dir(scan, jy, jx, jz)
  for label_filename = readdir(cell_labels_dir(scan, jy, jx, jz))
    endswith(label_filename, ".stl") || continue
    label_path = joinpath(labels_dir, label_filename)
    push!(labels, (label_filename, load(label_path)))
  end
  labels
end


# Potential

cell_potential_path(scan::HerculaneumScan, jy::Int, jx::Int, jz::Int) =
  joinpath(cell_segmentation_dir(scan, jy, jx, jz), "$(cell_name(jy, jx, jz))_potential.jld2")

have_cell_potential(scan::HerculaneumScan, jy::Int, jx::Int, jz::Int) =
  isfile(cell_potential_path(scan, jy, jx, jz))

load_cell_potential(scan::HerculaneumScan, jy::Int, jx::Int, jz::Int) =
  load(cell_potential_path(scan, jy, jx, jz), "ϕ", "S")

save_cell_potential(scan::HerculaneumScan, jy::Int, jx::Int, jz::Int, ϕ, S) =
  save(cell_potential_path(scan, jy, jx, jz), "ϕ", ϕ, "S", S)

potential_sheet_dir(scan::HerculaneumScan, jy::Int, jx::Int, jz::Int) =
  joinpath(cell_segmentation_dir(scan, jy, jx, jz), "sheets")

# Normals (Heat diffusion)

cell_normals_heat_path(scan::HerculaneumScan, jy::Int, jx::Int, jz::Int) =
  joinpath(cell_segmentation_dir(scan, jy, jx, jz), "$(cell_name(jy, jx, jz))_normals_heat.jld2")

have_cell_normals_heat(scan::HerculaneumScan, jy::Int, jx::Int, jz::Int) =
  isfile(cell_normals_heat_path(scan, jy, jx, jz))

load_cell_normals_heat(scan::HerculaneumScan, jy::Int, jx::Int, jz::Int) =
  load(cell_normals_heat_path(scan, jy, jx, jz), "N")

save_cell_normals_heat(scan::HerculaneumScan, jy::Int, jx::Int, jz::Int, N) =
  save(cell_normals_heat_path(scan, jy, jx, jz), "N", N)

# Normals (FFT)

cell_normals_fft_path(scan::HerculaneumScan, jy::Int, jx::Int, jz::Int) =
  joinpath(cell_segmentation_dir(scan, jy, jx, jz), "$(cell_name(jy, jx, jz))_normals_fft.jld2")

have_cell_normals_fft(scan::HerculaneumScan, jy::Int, jx::Int, jz::Int) =
  isfile(cell_normals_fft_path(scan, jy, jx, jz))

load_cell_normals_fft(scan::HerculaneumScan, jy::Int, jx::Int, jz::Int) =
  load(cell_normals_fft_path(scan, jy, jx, jz), "N", "P")

save_cell_normals_fft(scan::HerculaneumScan, jy::Int, jx::Int, jz::Int, N, P) =
  save(cell_normals_fft_path(scan, jy, jx, jz), "N", N, "P", P)


# Derivatives (Steger)

cell_derivatives_path(scan::HerculaneumScan, jy::Int, jx::Int, jz::Int) =
  joinpath(cell_segmentation_dir(scan, jy, jx, jz), "$(cell_name(jy, jx, jz))_derivatives.jld2")

have_cell_derivatives(scan::HerculaneumScan, jy::Int, jx::Int, jz::Int) =
  isfile(cell_derivatives_path(scan, jy, jx, jz))

load_cell_derivatives(scan::HerculaneumScan, jy::Int, jx::Int, jz::Int, names) =
  load(cell_derivatives_path(scan, jy, jx, jz), names...)


# Normals (Steger)

cell_normals_steger_path(scan::HerculaneumScan, jy::Int, jx::Int, jz::Int) =
  joinpath(cell_segmentation_dir(scan, jy, jx, jz), "$(cell_name(jy, jx, jz))_normals_steger.jld2")

have_cell_normals_steger(scan::HerculaneumScan, jy::Int, jx::Int, jz::Int) =
  isfile(cell_normals_steger_path(scan, jy, jx, jz))

load_cell_normals_steger(scan::HerculaneumScan, jy::Int, jx::Int, jz::Int) =
  load(cell_normals_steger_path(scan, jy, jx, jz), "N", "r")

save_cell_normals_steger(scan::HerculaneumScan, jy::Int, jx::Int, jz::Int, N, r) =
  save(cell_normals_steger_path(scan, jy, jx, jz), "N", N, "r", r)

cell_normals_relaxed_path(scan::HerculaneumScan, jy::Int, jx::Int, jz::Int) =
  cell_normals_steger_path(scan, jy, jx, jz)

have_cell_normals_relaxed(scan::HerculaneumScan, jy::Int, jx::Int, jz::Int) =
  have_cell_normals_steger(scan, jy, jx, jz)

load_cell_normals_relaxed(scan::HerculaneumScan, jy::Int, jx::Int, jz::Int) =
  load(cell_normals_steger_path(scan, jy, jx, jz), "Nr", "rr")

save_cell_normals_relaxed(scan::HerculaneumScan, jy::Int, jx::Int, jz::Int, Nr, rr) =
  jldopen(cell_normals_steger_path(scan, jy, jx, jz), "a+") do f
    f["Nr"] = Nr
    f["rr"] = rr
  end

