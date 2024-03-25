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
  cc -Wall -O3 -fPIC src/segment/snic.c -shared -o snic.so
  nm -D --defined-only snic.so

  # TODO: Adapt slic too, and compare performance.
  # cc -Wall -O3 -fPIC src/segment/slic.c -shared -o slic.so
  # nm -D --defined-only slic.so
}

build() {
  build_snic
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
