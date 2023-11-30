# Stabia

This repo, together with [vesuvius-blender](https://github.com/spelufo/vesuvius-blender) has code related to the [vesuvius challenge](https://scrollprize.org).

The workflow is usually to start a julia repl with `./dev.sh`, then
`include("src/stabia.jl")` and go from there. Re-include to reload code.

The `src/core` folder has the base utility library to manage the scan data.

The `src/editor` folder was an effort to build a custom editor, which I ended up
leaving aside in favor of building functionality into vesuvius-blender. The entry
point for this is `main.jl`, `start_stabia!`.

The `src/segment` folder has a few different attempts and ideas for automatic
segmentation. The function `run_ilastik_mesh_holes` in `ilastik.jl` is the
entry point to the process that generates holes meshes from cells of scan data.
