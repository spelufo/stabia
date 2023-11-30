#!/usr/bin/env bash

set -e

# export VESUVIUS_DATA_DIR="$(pwd)/../data"
export VESUVIUS_DATA_DIR="/mnt/vesuvius/data"
export VESUVIUS_SERVER_AUTH='registeredusers:only'
export MODERNGL_DEBUGGING=true

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
  julia
}

cmd="${1:-repl}"
shift || true
$cmd "$@"
