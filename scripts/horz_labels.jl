include("../src/stabia.jl")

labels_dir = "/mnt/phil/vesuvius/blender/pherc_1667_88"
labels_path = "$labels_dir/horz_labels_12_10_23.stl"
labels_mesh = load(labels_path)

labels_map = zeros(Bool, CELL_SIZE, CELL_SIZE, CELL_SIZE)
rasterize_mesh!(labels_map, labels_mesh, true, 12, 10, 23)
save("$labels_dir/horz_labels_12_10_23.tif", labels_map)
