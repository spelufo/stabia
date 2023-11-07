
# These are not the actual 5752 cells. I made a mistake and computed the cell
# indexes without accounting for 0->1 based indexing and xy -> yx cell coords.
# So when running top_pipeline I ended up computing holes for these insead of
# the ones that I intended (the ones touching 5752). I've fixed this, but will
# leave this cells here unchanged for the record. They could come in handy.
cells_wrong_5752_run = [
  (5, 4, 5),
  (5, 4, 6),
  (5, 4, 7),
  (5, 4, 8),
  (5, 4, 9),
  (5, 5, 15),
  (5, 5, 16),
  (5, 5, 17),
  (5, 5, 18),
  (5, 5, 19),
  (5, 5, 6),
  (5, 5, 7),
  (5, 5, 8),
  (5, 6, 16),
  (5, 6, 17),
  (5, 6, 18),
  (5, 6, 19),
  (5, 6, 20),
  (5, 7, 17),
  (5, 7, 18),
  (5, 7, 19),
  (5, 7, 20),
  (5, 8, 19),
  (5, 8, 20),
  (6, 4, 10),
  (6, 4, 11),
  (6, 4, 4),
  (6, 4, 5),
  (6, 4, 6),
  (6, 4, 7),
  (6, 4, 8),
  (6, 4, 9),
  (6, 5, 10),
  (6, 5, 11),
  (6, 5, 12),
  (6, 5, 13),
  (6, 5, 14),
  (6, 5, 15),
  (6, 5, 16),
  (6, 5, 17),
  (6, 5, 18),
  (6, 5, 19),
  (6, 5, 20),
  (6, 5, 4),
  (6, 5, 5),
  (6, 5, 6),
  (6, 5, 7),
  (6, 5, 8),
  (6, 5, 9),
  (6, 6, 10),
  (6, 6, 11),
  (6, 6, 12),
  (6, 6, 13),
  (6, 6, 14),
  (6, 6, 15),
  (6, 6, 16),
  (6, 6, 17),
  (6, 6, 18),
  (6, 6, 19),
  (6, 6, 20),
  (6, 7, 11),
  (6, 7, 12),
  (6, 7, 13),
  (6, 7, 14),
  (6, 7, 15),
  (6, 7, 16),
  (6, 7, 17),
  (6, 7, 18),
  (6, 7, 19),
  (6, 7, 20),
  (6, 8, 15),
  (6, 8, 16),
  (6, 8, 17),
  (6, 8, 18),
  (6, 8, 19),
  (6, 8, 20),
  (7, 3, 4),
  (7, 3, 5),
  (7, 3, 6),
  (7, 3, 7),
  (7, 3, 8),
  (7, 4, 10),
  (7, 4, 11),
  (7, 4, 4),
  (7, 4, 5),
  (7, 4, 6),
  (7, 4, 7),
  (7, 4, 8),
  (7, 4, 9),
  (7, 5, 10),
  (7, 5, 11),
  (7, 5, 12),
  (7, 5, 13),
  (7, 5, 14),
  (7, 5, 15),
  (7, 5, 16),
  (7, 5, 17),
  (7, 5, 18),
  (7, 5, 19),
  (7, 5, 4),
  (7, 5, 5),
  (7, 5, 6),
  (7, 5, 7),
  (7, 5, 8),
  (7, 5, 9),
  (7, 6, 10),
  (7, 6, 11),
  (7, 6, 12),
  (7, 6, 13),
  (7, 6, 14),
  (7, 6, 15),
  (7, 6, 16),
  (7, 6, 17),
  (7, 6, 18),
  (7, 6, 19),
  (7, 6, 20),
  (7, 6, 9),
  (7, 7, 11),
  (7, 7, 12),
  (7, 7, 13),
  (7, 7, 14),
  (7, 7, 15),
  (7, 7, 16),
  (7, 7, 17),
  (7, 7, 18),
  (7, 7, 19),
  (7, 7, 20),
  (7, 8, 14),
  (7, 8, 15),
  (7, 8, 16),
  (7, 8, 17),
  (7, 8, 18),
  (7, 8, 19),
  (7, 8, 20), # Done all from the first one to this one here!
  (8, 3, 4),
  (8, 3, 5),
  (8, 3, 6),
  (8, 3, 7),
  (8, 3, 8),
  (8, 4, 10),
  (8, 4, 11),
  (8, 4, 4),
  (8, 4, 5),
  (8, 4, 6),
  (8, 4, 7),
  (8, 4, 8),
  (8, 4, 9),
  (8, 5, 10),
  (8, 5, 11),
  (8, 5, 12),
  (8, 5, 13),
  (8, 5, 4),
  (8, 5, 5),
  (8, 5, 7),
  (8, 5, 9),
  (8, 6, 10),
  (8, 6, 11),
  (8, 6, 12),
  (8, 6, 13),
  (8, 6, 14),
  (8, 6, 15),
  (8, 6, 16),
  (8, 6, 17),
  (8, 6, 9),
  (8, 7, 11),
  (8, 7, 12),
  (8, 7, 13),
  (8, 7, 14),
  (8, 7, 15),
  (8, 7, 16),
  (8, 7, 17),
  (9, 3, 5),
  (9, 3, 6),
  (9, 3, 7),
  (9, 4, 10),
  (9, 4, 4),
  (9, 4, 5),
  (9, 4, 6),
  (9, 4, 7),
  (9, 4, 8),
  (9, 4, 9),
  (9, 5, 10),
  (9, 5, 4),
  (9, 5, 9),
]

cells = [
  (11, 7, 22),
]


run_convert_to_h5() = begin
  for (jy, jx, jz) in cells
    println("Converting $jy, $jx, $jz ...")
    cell_to_h5(scroll_1_54, jy, jx, jz)
    GC.gc()
    sleep(0.5)
  end
end

# 6, 8, 17 as reference
# omnidirectional smoothing.

# Chose all features. Labeled.

# Run ilastik pixel classification "Suggest Features (4):"
#   Gaussian Smoothing (σ=0.7)
#   Gaussian Smoothing (σ=3.5)
#   Structure Tensor Eigenvalues (σ=10.0) [2]
#   Hessian of Gaussian Eigenvalues (σ=1.6) [0]

# Then removed the first, which I think is approx. the value of the px.

#   Gaussian Smoothing (σ=3.5)
#   Structure Tensor Eigenvalues (σ=10.0) [2]
#   Hessian of Gaussian Eigenvalues (σ=1.6) [0]



include("../src/stabia.jl")
include("../src/segment/ilastik.jl")

const CELLS_DIR = "../data/full-scrolls/Scroll1.volpkg/volume_grids/20230205180739"
const SEGDATA_DIR = "../data/full-scrolls/Scroll1.volpkg/segmentation"
# isdir(SEGDATA_DIR) || mkdir(SEGDATA_DIR)


top_pipeline(cell_jy::Int, cell_jx::Int, cell_jz::Int) = begin
  # 0. Setup.
  cell_name = cell_name(cell_jy, cell_jx, cell_jz)
  cell_dir = "$SEGDATA_DIR/$cell_name"
  isdir(cell_dir) || mkdir(cell_dir)
  cell_h5_file = cell_h5_path(scroll_1_54, cell_jy, cell_jx, cell_jz)

  # 3. Ilastik pixel classification. `*_probabilities.h5`     (1000M) ( 180s)
  probabilities_file = "$cell_dir/$(cell_name)_probabilities.h5"
  @time if !isfile(probabilities_file)
    println("Running ilastik pixel classification...")
    run(pipeline(
      `/opt/ilastik/run_ilastik.sh --project /mnt/phil/vesuvius/ilastik/PixelClassification_06_08_17.ilp 
      --headless --readonly
      --export_source Probabilities
      --output_filename_format $probabilities_file
      $cell_h5_file`,
      stdout="/tmp/ilastik_pixel_classification.log",
      stderr="/tmp/ilastik_pixel_classification.log"))
    # TODO: Maybe try configuring the project with less features and see if it
    # works just as well, so that it is faster. After having the whole pipeline.
  end

  # 4. Ilastik segmentation.         `*_hole_ids.h5`          ( 500M) (  28s)
  hole_ids_file = "$cell_dir/$(cell_name)_hole_ids.h5"
  @time if !isfile(hole_ids_file)
    println("Running ilastik segmentation...")
    run(pipeline(
      `/opt/ilastik/run_ilastik.sh --project /mnt/phil/vesuvius/ilastik/ObjectClassification_06_08_17.ilp
      --headless --readonly
      --export_source 'Object Identities'
      --output_filename_format $hole_ids_file
      --raw_data $cell_h5_file
      --prediction_maps $cell_dir/$(cell_name)_probabilities.h5`,
      stdout="/tmp/ilastik_segmentation.log",
      stderr="/tmp/ilastik_segmentation.log"))
  end


  # 5. Marching cubes.               `holes/*.stl`             ( 750M) ( 35s)
  hole_dir = "$cell_dir/holes"
  @time if !isdir(hole_dir)
    println("Building hole meshes...")
    mkdir(hole_dir)
    cell_pos = Point3f(500f0 * (cell_jx-1), 500f0 * (cell_jy-1), 500f0 * (cell_jz-1))
    hole_ids_to_meshes(hole_ids_file, "$hole_dir/$(cell_name)_hole_", cell_pos)
  end

  # 6. Cleanup intermediate files.
  # rm(raw_h5_file)
  # rm(probabilities_file)
  # rm(hole_ids_file)

  nothing
end


run_all() = begin
  for (jy, jx, jz) = cells
    println("==============================================================")
    println("==============================================================")
    println("Running ", (jy, jx, jz))
    println()
    @time top_pipeline(jy, jx, jz)
    sleep(5)
    GC.gc()
    println()
    println()
  end
end
