# Sheet Adjustmend and Assembly HOWTO

This outlines the steps used to do segment adjustment and assembly of the GP
banner segments. The accompanying pdf document explains what this is about and
how it is achieved.

## Outline

H: human, C: computer

- H: Setup
- C: SNIC superpixels
- C: Sheet adjustment
- C: Assembler
- H: Assembly post-processing
- C: Poisson Surface Reconstruction
- H: Trim, weld and clean half turn meshes
- C: ACVD remesh
- H: Unwrap and fix genus

---

# Setup

Requirements:

- At least 16GB of RAM.
- A reasonably fast SSD with plenty of space. GP cells are ~300GB and we need
  space for generated files. 1TB is probably more than enough.
- Blender installed (3.6)
- Vesuvius-blender installed.
- The julia programming language installed.
- The stabia repository and its dependencies:
  - `./dev.sh`, then `]instantiate`.
  - `./dev.sh sysimage` to build the sysimage.
- The grid cells covering the gp segments:
  - `./dev.sh`, then `julia> download_cells(scroll_1_54, eachrow(scroll_1_54_gp_mask))`

All commands must be run from the root of the stabia repository, from a bash
shell or the julia shell started with `./dev.sh`.


# SNIC superpixels

Run simultaneously, in different julia processes:

```julia
build_snic(scroll_1_54, scroll_1_54_gp_mask[1:100,:]) # 101:200, 201:300, ...
```

Build snic superpixels for GP segment cells. I run 5-6 processes working on
subsets of the cells. Multithreading and multiprocessing didn't speed things up
by much, probably because the bottleneck is L3. It did the 754 cells in 20hs on
my dell g7 laptop. The results are 30GB: 17GB in snic_labels and 23GB in snic
superpixels.

That's 95.5 s/cell, which would mean ~4 days for all of scroll_1_54_mask.


# Sheet adjustment

Run the following to split the segment meshes into cell sized chunks.

```sh
python -m stabia splitter $VESUVIUS_DATA/full-scrolls/Scroll1.volpkg
```

Next run the segment adjustment procedure. Like SNIC, run it simultaneously in
different processes, for each layer between 1 and 29:

```julia
build_sadjs_gp_layer(1) # 2, 3, ..., 29.
```

Running six processes simultaneously, it took ~8hs for 24 gp layers, with an
average runtime of 259 s/cell. That means it would take 11 days to run as is on
scroll_1_54: `259 * size(scroll_1_54_mask, 1) / 3600 / 24 ≈ 11 days`.


# Assembler

```julia
assemble_scroll(scroll_1_54)
```

Go through the svg images generated in `logs/assembler` to debug the output.


# Assembly post-processing

The assembler will have generated results that for the most part outline the
turns of the scroll and generated a python script that imports the chunks of
each turn (as point clouds) into separate blender collection.

TODO: Document this process.


# Poisson Surface Reconstruction


```julia
build_recon_halves(scroll_1_54, "logs/gp_adjustment/recon_20", "logs/gp_adjustment/scroll_1_assembly.json")
```


# Trim, weld and clean half turn meshes

TODO: Document this process.

```sh
python -m stabia mesh_report logs/gp_adjustment/recon_20/cols/*
```


# ACVD remesh

```julia
remesh_column_meshes("logs/gp_adjustment/recon_20/cols", "logs/gp_adjustment/recon_20/cols_acvd")
```


# Unwrap and fix genus

TODO: Document this process.


# Mesh texture initialization for surface volume rendering

WIP, document when done.

```sh
cd ../repos/ThaumatoAnakalyptor
for f in ../../stabia/logs/gp_adjustment/recon_20/cols_to_render/turn_??_h?.obj; do
  python -m ThaumatoAnakalyptor.mesh_texture_init $f
done
  ```
