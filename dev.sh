#!/usr/bin/env bash

set -e

if [ -f env.sh ]; then
  . env.sh
fi

julia() {
  sysimage='./stabia_sysimage.so'
  sysimagearg=''
  if [ -f "$sysimage" ]; then
    sysimagearg="--sysimage=$sysimage"
  else
    echo 'WARNING: sysimage not found. For best performance build one by running `./dev.sh sysimage`'
  fi
  prime-run julia --project=. $sysimagearg "$@"
}

sysimage() {
  prime-run julia --project=. scripts/create_sysimage.jl
}

test() {
  julia test/runtests.jl
}

repl() {
  build
  julia
}

build_snic() {
  if [ ! -f ./snic.so ]; then
    cc -Wall -O3 -fPIC src/build/snic.c -shared -o snic.so
    nm -D --defined-only snic.so
  fi

  # TODO: Adapt slic too, and compare performance.
  # cc -Wall -O3 -fPIC src/build/slic.c -shared -o slic.so
  # nm -D --defined-only slic.so
}

build_recon() {
  (
    cd recon
    make poissonvesuvius
  )
  cp recon/Bin/Linux/PoissonVesuvius.so recon.so
}

build() {
  build_recon
  build_snic
}

clean() {
  (cd recon; make clean)
  rm snic.so
  # rm stabia_sysimage.so
}

grids_docker_build() {
  docker build --tag spelufo/stabia-grids:latest -f envs/grids/Dockerfile .
}
grids_docker_run() {
  volpkg="$1"
  scanid="$2"
  shift; shift
  if [ ! -f "$VESUVIUS_DATA_DIR/$volpkg/volumes/$scanid/meta.json" ]; then
    echo "usage: ./dev.sh grids_docker_run \$volpkg \$scanid"
    exit 1
  fi
  exec docker run --name stabia-grids \
    -e "VESUVIUS_SERVER_AUTH=$VESUVIUS_SERVER_AUTH" -e JULIA_NUM_THREADS=auto \
    -v "$VESUVIUS_DATA_DIR:/mnt/vesuvius/data:ro" \
    -v "$VESUVIUS_DATA_DIR/$volpkg/volume_grids:/mnt/vesuvius/data/$volpkg/volume_grids:rw" \
    -v "$VESUVIUS_DATA_DIR/$volpkg/volumes_small:/mnt/vesuvius/data/$volpkg/volumes_small:rw" \
    -it spelufo/stabia-grids:latest "$@"
}

# run_gdb() {
#   build && command gdb -ex "break __assert_fail" -ex run  --args ./main "$tif"
# }

# run_valgr() {
#   build && valgrind ./main "$tif"
# }

# build_wasm() {
#   clang --target=wasm32 -nostdlib -Wl,--no-entry -Wl,--allow-undefined -Wl,--export-all -o public/main.wasm src/main.c
# }


cmd="${1:-repl}"
shift || true
$cmd "$@"
