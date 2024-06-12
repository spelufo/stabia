
### Start the container

```bash

docker run \
    -e "VESUVIUS_SERVER_AUTH=$VESUVIUS_SERVER_AUTH" -e JULIA_NUM_THREADS=auto \
    -v "$VESUVIUS_DATA_DIR:/mnt/vesuvius/data:ro" \
    -v "$VESUVIUS_DATA_DIR/$volpkg/volume_grids:/mnt/vesuvius/data/$volpkg/volume_grids:rw" \
    -v "$VESUVIUS_DATA_DIR/$volpkg/volumes_small:/mnt/vesuvius/data/$volpkg/volumes_small:rw" \
    -it spelufo/stabia-grids:latest
```

### Build volumes_small

```
julia> include("src/stabia.jl")
build_small_volume

# Define a variable with the scroll metadata, loaded from the meta.json.
# Use tab completion to find the right file for the desired scan.
julia> scroll = scan_from_meta("/mnt/vesuvius/data/full-scrolls/ScrollX/Y.volpkg/volumes/20230101000000/meta.json")
HerculaneumScan("full-scrolls/Scroll1/PHercParis4.volpkg", "20230101000000", 7.91f0, 54.0f0, 8096, 7888, 14376)

julia> build_small_volume(scroll, from=:disk)

```


### Build volume_grids

```
julia> include("src/stabia.jl")
build_small_volume

# Define a variable with the scroll metadata, loaded from the meta.json.
# Use tab completion to find the right file for the desired scan.
julia> scroll = scan_from_meta("/mnt/vesuvius/data/full-scrolls/ScrollX/Y.volpkg/volumes/20230101000000/meta.json")
HerculaneumScan("full-scrolls/Scroll1/PHercParis4.volpkg", "20230101000000", 7.91f0, 54.0f0, 8096, 7888, 14376)

julia> build_grid(scroll)

```
