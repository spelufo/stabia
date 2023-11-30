include("../src/stabia.jl")

# These are the segments through cell (11,7,22), which is on segment 3333.
segment_ids = [
  "20231012173610",
  "20231007101615",
  "20231005123333",
  "20230929220924",
  "20230522215721",
]

# These are all the cells through those segments + eyeball z extension down.
# cellsets = [segment_cells(scroll_1_54, segment_id) for segment_id in segment_ids];
# push!(cellsets, mesh_cells(load("z_extend_333.stl")))
# cells = sort(collect(reduce(union, cellsets)); by= c -> -c[3])
cells = [
  (6, 5, 25),
  (6, 6, 25),
  (6, 7, 25),
  (7, 5, 25),
  (7, 6, 25),
  (7, 7, 25),
  (7, 8, 25),
  (7, 9, 25),
  (8, 5, 25),
  (8, 7, 25),
  (8, 8, 25),
  (8, 9, 25),
  (8, 10, 25),
  (9, 5, 25),
  (9, 6, 25),
  (9, 8, 25),
  (9, 9, 25),
  (10, 5, 25),
  (10, 6, 25),
  (10, 7, 25),
  (10, 8, 25),
  (10, 9, 25),
  (11, 5, 25),
  (11, 6, 25),
  (11, 7, 25),
  (11, 8, 25),
  (11, 9, 25),
  (12, 6, 25),
  (12, 7, 25),
  (12, 8, 25),
  (13, 6, 25),
  (13, 7, 25),
  (6, 5, 24),
  (6, 6, 24),
  (6, 7, 24),
  (7, 5, 24),
  (7, 6, 24),
  (7, 7, 24),
  (7, 8, 24),
  (7, 9, 24),
  (8, 5, 24),
  (8, 7, 24),
  (8, 8, 24),
  (8, 9, 24),
  (8, 10, 24),
  (9, 5, 24),
  (9, 6, 24),
  (9, 8, 24),
  (9, 9, 24),
  (10, 5, 24),
  (10, 6, 24),
  (10, 7, 24),
  (10, 8, 24),
  (10, 9, 24),
  (11, 5, 24),
  (11, 6, 24),
  (11, 7, 24),
  (11, 8, 24),
  (11, 9, 24),
  (12, 5, 24),
  (12, 6, 24),
  (12, 7, 24),
  (12, 8, 24),
  (13, 6, 24),
  (13, 7, 24),
  (5, 6, 23),
  (6, 5, 23),
  (6, 6, 23),
  (6, 7, 23),
  (6, 8, 23),
  (7, 5, 23),
  (7, 6, 23),
  (7, 7, 23),
  (7, 8, 23),
  (7, 9, 23),
  (8, 5, 23),
  (8, 6, 23),
  (8, 8, 23),
  (8, 9, 23),
  (8, 10, 23),
  (9, 5, 23),
  (9, 6, 23),
  (9, 8, 23),
  (9, 9, 23),
  (9, 10, 23),
  (10, 5, 23),
  (10, 6, 23),
  (10, 7, 23),
  (10, 8, 23),
  (10, 9, 23),
  (11, 5, 23),
  (11, 6, 23),
  (11, 7, 23),
  (11, 8, 23),
  (11, 9, 23),
  (12, 5, 23),
  (12, 6, 23),
  (12, 7, 23),
  (12, 8, 23),
  (5, 5, 22),
  (5, 6, 22),
  (5, 7, 22),
  (6, 5, 22),
  (6, 6, 22),
  (6, 7, 22),
  (6, 8, 22),
  (6, 9, 22),
  (7, 5, 22),
  (7, 6, 22),
  (7, 7, 22),
  (7, 8, 22),
  (7, 9, 22),
  (7, 10, 22),
  (8, 5, 22),
  (8, 6, 22),
  (8, 8, 22),
  (8, 9, 22),
  (8, 10, 22),
  (9, 5, 22),
  (9, 6, 22),
  (9, 8, 22),
  (9, 9, 22),
  (9, 10, 22),
  (10, 5, 22),
  (10, 6, 22),
  (10, 7, 22),
  (10, 8, 22),
  (10, 9, 22),
  (11, 5, 22),
  (11, 6, 22),
  (11, 7, 22),
  (11, 8, 22),
  (11, 9, 22),
  (12, 6, 22),
  (12, 7, 22),
  (12, 8, 22),
  (5, 5, 21),
  (5, 6, 21),
  (5, 7, 21),
  (5, 8, 21),
  (6, 5, 21),
  (6, 6, 21),
  (6, 7, 21),
  (6, 8, 21),
  (6, 9, 21),
  (7, 5, 21),
  (7, 6, 21),
  (7, 8, 21),
  (7, 9, 21),
  (7, 10, 21),
  (8, 5, 21),
  (8, 6, 21),
  (8, 8, 21),
  (8, 9, 21),
  (8, 10, 21),
  (9, 5, 21),
  (9, 6, 21),
  (9, 7, 21),
  (9, 8, 21),
  (9, 9, 21),
  (9, 10, 21),
  (10, 5, 21),
  (10, 6, 21),
  (10, 7, 21),
  (10, 8, 21),
  (10, 9, 21),
  (10, 10, 21),
  (11, 5, 21),
  (11, 6, 21),
  (11, 7, 21),
  (11, 8, 21),
  (11, 9, 21),
  (12, 8, 21),
  (5, 5, 20),
  (5, 6, 20),
  (5, 7, 20),
  (5, 8, 20),
  (6, 5, 20),
  (6, 6, 20),
  (6, 7, 20),
  (6, 8, 20),
  (6, 9, 20),
  (6, 10, 20),
  (7, 5, 20),
  (7, 6, 20),
  (7, 8, 20),
  (7, 9, 20),
  (7, 10, 20),
  (8, 5, 20),
  (8, 6, 20),
  (8, 8, 20),
  (8, 9, 20),
  (8, 10, 20),
  (9, 5, 20),
  (9, 6, 20),
  (9, 7, 20),
  (9, 8, 20),
  (9, 9, 20),
  (9, 10, 20),
  (10, 6, 20),
  (10, 7, 20),
  (10, 8, 20),
  (10, 9, 20),
  (10, 10, 20),
  (11, 6, 20),
  (11, 7, 20),
  (11, 8, 20),
  (11, 9, 20),
  (5, 5, 19),
  (5, 6, 19),
  (5, 7, 19),
  (5, 8, 19),
  (6, 5, 19),
  (6, 6, 19),
  (6, 7, 19),
  (6, 8, 19),
  (6, 9, 19),
  (6, 10, 19),
  (7, 5, 19),
  (7, 6, 19),
  (7, 8, 19),
  (7, 9, 19),
  (7, 10, 19),
  (8, 5, 19),
  (8, 6, 19),
  (8, 7, 19),
  (8, 8, 19),
  (8, 9, 19),
  (8, 10, 19),
  (9, 5, 19),
  (9, 6, 19),
  (9, 7, 19),
  (9, 8, 19),
  (9, 9, 19),
  (9, 10, 19),
  (10, 6, 19),
  (10, 7, 19),
  (10, 8, 19),
  (10, 9, 19),
  (10, 10, 19),
  (11, 7, 19),
  (11, 8, 19),
  (11, 9, 19),
  (5, 5, 18),
  (5, 6, 18),
  (5, 7, 18),
  (5, 8, 18),
  (6, 5, 18),
  (6, 6, 18),
  (6, 7, 18),
  (6, 8, 18),
  (6, 9, 18),
  (6, 10, 18),
  (7, 5, 18),
  (7, 6, 18),
  (7, 8, 18),
  (7, 9, 18),
  (7, 10, 18),
  (8, 5, 18),
  (8, 6, 18),
  (8, 7, 18),
  (8, 9, 18),
  (8, 10, 18),
  (9, 6, 18),
  (9, 7, 18),
  (9, 8, 18),
  (9, 9, 18),
  (9, 10, 18),
  (10, 6, 18),
  (10, 7, 18),
  (10, 8, 18),
  (10, 9, 18),
  (5, 5, 17),
  (5, 6, 17),
  (5, 7, 17),
  (5, 8, 17),
  (6, 5, 17),
  (6, 6, 17),
  (6, 7, 17),
  (6, 8, 17),
  (6, 9, 17),
  (6, 10, 17),
  (7, 6, 17),
  (7, 7, 17),
  (7, 8, 17),
  (7, 9, 17),
  (7, 10, 17),
  (7, 11, 17),
  (8, 6, 17),
  (8, 7, 17),
  (8, 9, 17),
  (8, 10, 17),
  (9, 6, 17),
  (9, 7, 17),
  (9, 8, 17),
  (9, 9, 17),
  (9, 10, 17),
  (10, 6, 17),
  (10, 7, 17),
  (10, 8, 17),
  (10, 9, 17),
  (5, 5, 16),
  (5, 6, 16),
  (5, 7, 16),
  (5, 8, 16),
  (5, 9, 16),
  (5, 10, 16),
  (6, 5, 16),
  (6, 6, 16),
  (6, 7, 16),
  (6, 8, 16),
  (6, 9, 16),
  (6, 10, 16),
  (6, 11, 16),
  (7, 5, 16),
  (7, 6, 16),
  (7, 8, 16),
  (7, 9, 16),
  (7, 10, 16),
  (7, 11, 16),
  (8, 9, 16),
  (8, 10, 16),
  (8, 11, 16),
  (9, 9, 16),
  (9, 10, 16),
  (9, 11, 16),
  (5, 6, 15),
  (5, 7, 15),
  (5, 8, 15),
  (5, 9, 15),
  (5, 10, 15),
  (6, 7, 15),
  (6, 8, 15),
  (6, 9, 15),
  (6, 10, 15),
  (6, 11, 15),
  (7, 5, 15),
  (7, 6, 15),
  (7, 7, 15),
  (7, 8, 15),
  (7, 9, 15),
  (7, 10, 15),
  (7, 11, 15),
  (8, 6, 15),
  (8, 7, 15),
  (8, 8, 15),
  (8, 9, 15),
  (8, 10, 15),
  (8, 11, 15),
  (9, 6, 15),
  (9, 7, 15),
  (9, 8, 15),
  (9, 9, 15),
  (9, 10, 15),
  (9, 11, 15),
  (10, 7, 15),
  (10, 8, 15),
  (4, 6, 14),
  (4, 7, 14),
  (4, 8, 14),
  (4, 9, 14),
  (5, 5, 14),
  (5, 6, 14),
  (5, 7, 14),
  (5, 8, 14),
  (5, 9, 14),
  (5, 10, 14),
  (5, 11, 14),
  (6, 5, 14),
  (6, 6, 14),
  (6, 7, 14),
  (6, 9, 14),
  (6, 10, 14),
  (6, 11, 14),
  (6, 12, 14),
  (7, 5, 14),
  (7, 6, 14),
  (7, 7, 14),
  (7, 8, 14),
  (7, 10, 14),
  (7, 11, 14),
  (7, 12, 14),
  (8, 5, 14),
  (8, 6, 14),
  (8, 7, 14),
  (8, 8, 14),
  (8, 9, 14),
  (8, 10, 14),
  (8, 11, 14),
  (8, 12, 14),
  (9, 6, 14),
  (9, 7, 14),
  (9, 8, 14),
  (9, 9, 14),
  (9, 10, 14),
  (9, 11, 14),
  (10, 7, 14),
  (10, 8, 14),
  (4, 5, 13),
  (4, 6, 13),
  (4, 7, 13),
  (4, 8, 13),
  (4, 9, 13),
  (5, 4, 13),
  (5, 5, 13),
  (5, 6, 13),
  (5, 7, 13),
  (5, 8, 13),
  (5, 9, 13),
  (5, 10, 13),
  (5, 11, 13),
  (6, 4, 13),
  (6, 5, 13),
  (6, 6, 13),
  (6, 7, 13),
  (6, 8, 13),
  (6, 9, 13),
  (6, 10, 13),
  (6, 11, 13),
  (6, 12, 13),
  (7, 4, 13),
  (7, 5, 13),
  (7, 6, 13),
  (7, 7, 13),
  (7, 8, 13),
  (7, 9, 13),
  (7, 10, 13),
  (7, 11, 13),
  (7, 12, 13),
  (8, 5, 13),
  (8, 6, 13),
  (8, 7, 13),
  (8, 8, 13),
  (8, 9, 13),
  (8, 10, 13),
  (8, 11, 13),
  (8, 12, 13),
  (9, 5, 13),
  (9, 6, 13),
  (9, 7, 13),
  (9, 8, 13),
  (9, 9, 13),
  (9, 10, 13),
  (9, 11, 13),
  (10, 6, 13),
  (10, 7, 13),
  (10, 8, 13),
  (10, 9, 13),
  (10, 10, 13),
  (4, 4, 12),
  (4, 5, 12),
  (4, 6, 12),
  (4, 7, 12),
  (4, 8, 12),
  (4, 9, 12),
  (5, 4, 12),
  (5, 5, 12),
  (5, 6, 12),
  (5, 7, 12),
  (5, 12, 12),
  (6, 4, 12),
  (6, 5, 12),
  (6, 6, 12),
  (6, 7, 12),
  (6, 8, 12),
  (6, 12, 12),
  (7, 4, 12),
  (7, 5, 12),
  (7, 6, 12),
  (7, 7, 12),
  (7, 8, 12),
  (7, 9, 12),
  (7, 10, 12),
  (7, 12, 12),
  (8, 4, 12),
  (8, 5, 12),
  (8, 6, 12),
  (8, 7, 12),
  (8, 8, 12),
  (8, 9, 12),
  (8, 10, 12),
  (9, 5, 12),
  (9, 6, 12),
  (9, 7, 12),
  (9, 8, 12),
  (9, 9, 12),
  (9, 10, 12),
  (10, 7, 12),
  (10, 8, 12),
  (10, 9, 12),
  (5, 8, 12),
  (5, 9, 12),
  (5, 10, 12),
  (5, 11, 12),
  (6, 9, 12),
  (6, 10, 12),
  (6, 11, 12),
  (7, 11, 12),
  (4, 4, 11),
  (4, 5, 11),
  (4, 6, 11),
  (4, 7, 11),
  (4, 8, 11),
  (4, 9, 11),
  (4, 10, 11),
  (4, 11, 11),
  (5, 4, 11),
  (5, 5, 11),
  (5, 6, 11),
  (5, 7, 11),
  (5, 8, 11),
  (5, 9, 11),
  (5, 10, 11),
  (5, 11, 11),
  (5, 12, 11),
  (6, 4, 11),
  (6, 5, 11),
  (6, 6, 11),
  (6, 7, 11),
  (6, 8, 11),
  (6, 9, 11),
  (6, 10, 11),
  (6, 11, 11),
  (6, 12, 11),
  (7, 4, 11),
  (7, 5, 11),
  (7, 6, 11),
  (7, 7, 11),
  (7, 8, 11),
  (7, 9, 11),
  (7, 10, 11),
  (7, 11, 11),
  (7, 12, 11),
  (8, 5, 11),
  (8, 6, 11),
  (8, 7, 11),
  (8, 8, 11),
  (8, 9, 11),
  (8, 10, 11),
  (8, 11, 11),
  (9, 7, 11),
  (9, 8, 11),
  (9, 9, 11),
  (9, 10, 11),
  (3, 8, 10),
  (3, 9, 10),
  (4, 4, 10),
  (4, 5, 10),
  (4, 6, 10),
  (4, 7, 10),
  (4, 8, 10),
  (4, 9, 10),
  (4, 12, 10),
  (5, 4, 10),
  (5, 5, 10),
  (5, 6, 10),
  (5, 7, 10),
  (5, 8, 10),
  (5, 9, 10),
  (5, 12, 10),
  (6, 4, 10),
  (6, 5, 10),
  (6, 6, 10),
  (6, 7, 10),
  (6, 8, 10),
  (6, 9, 10),
  (6, 11, 10),
  (6, 12, 10),
  (7, 4, 10),
  (7, 5, 10),
  (7, 6, 10),
  (7, 7, 10),
  (7, 8, 10),
  (7, 9, 10),
  (7, 11, 10),
  (7, 12, 10),
  (8, 7, 10),
  (8, 8, 10),
  (8, 9, 10),
  (8, 10, 10),
  (8, 11, 10),
  (9, 9, 10),
  (9, 10, 10),
  (7, 10, 10),
  (6, 10, 10),
  (5, 10, 10),
  (4, 10, 10),
  (3, 10, 10),
  (5, 11, 10),
  (4, 11, 10),
  (3, 8, 9),
  (3, 9, 9),
  (4, 4, 9),
  (4, 5, 9),
  (4, 6, 9),
  (4, 7, 9),
  (4, 8, 9),
  (4, 9, 9),
  (4, 10, 9),
  (4, 11, 9),
  (4, 12, 9),
  (5, 4, 9),
  (5, 5, 9),
  (5, 6, 9),
  (5, 7, 9),
  (5, 8, 9),
  (5, 9, 9),
  (5, 10, 9),
  (5, 11, 9),
  (5, 12, 9),
  (5, 13, 9),
  (6, 4, 9),
  (6, 5, 9),
  (6, 6, 9),
  (6, 7, 9),
  (6, 8, 9),
  (6, 9, 9),
  (6, 10, 9),
  (6, 11, 9),
  (6, 12, 9),
  (7, 4, 9),
  (7, 5, 9),
  (7, 6, 9),
  (7, 7, 9),
  (7, 8, 9),
  (7, 9, 9),
  (7, 10, 9),
  (7, 11, 9),
  (8, 5, 9),
  (8, 6, 9),
  (8, 7, 9),
  (8, 8, 9),
  (8, 9, 9),
  (8, 10, 9),
  (8, 11, 9),
  (9, 8, 9),
  (9, 9, 9),
  (3, 9, 8),
  (4, 4, 8),
  (4, 5, 8),
  (4, 6, 8),
  (4, 7, 8),
  (4, 8, 8),
  (4, 9, 8),
  (4, 10, 8),
  (4, 11, 8),
  (4, 12, 8),
  (5, 4, 8),
  (5, 5, 8),
  (5, 6, 8),
  (5, 7, 8),
  (5, 8, 8),
  (5, 9, 8),
  (5, 10, 8),
  (5, 11, 8),
  (5, 12, 8),
  (6, 4, 8),
  (6, 5, 8),
  (6, 6, 8),
  (6, 7, 8),
  (6, 8, 8),
  (6, 9, 8),
  (6, 10, 8),
  (6, 11, 8),
  (6, 12, 8),
  (7, 5, 8),
  (7, 6, 8),
  (7, 7, 8),
  (7, 8, 8),
  (7, 9, 8),
  (7, 10, 8),
  (7, 11, 8),
  (8, 5, 8),
  (8, 6, 8),
  (8, 7, 8),
  (8, 8, 8),
  (8, 10, 8),
  (8, 11, 8),
]

# download_cells(scroll_1_54, cells)

n_total = length(cells)
remaining_cells = filter(c -> !have_cell_holes(scroll_1_54, c...), cells)
n_remaining = length(remaining_cells)
@show n_total n_remaining

for (jy, jx, jz) in remaining_cells
  println("Running ilastik_mesh_holes on cell $((jy, jx, jz))...")
  run_ilastik_mesh_holes(scroll_1_54, jy, jx, jz)
  println("Done running ilastik_mesh_holes on cell $((jy, jx, jz)).\n\n")
  GC.gc()
  space = parse(Int, split(read(`df --output=avail /mnt/phil/`, String), "\n")[2])
  if space < 30*1024*1024
    println("Too little space left on drive, aborting.")
    break
  end
  println()
  sleep(3)
end