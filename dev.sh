#!/usr/bin/env bash

set -e

export VESUVIUS_DATA_DIR="$(pwd)/../data"
export VESUVIUS_SERVER_AUTH='registeredusers:only'

julia() {
  # Leave one thread unused.
  # Otherwise sometimes when I run something it freezes the machine.
  export JULIA_NUM_THREADS=11
  sysimage='./src/sysimage/stabia_deps_sysimage.so'
  sysimagearg=''
  if [ -f "$sysimage" ]; then
    sysimagearg="--sysimage=$sysimage"
  else
    echo 'WARNING: sysimage not found. For best performance build one by running `./dev.sh sysimage`'
  fi
  command julia --project=. $sysimagearg "$@"
}

sysimage() {
  command julia --project=. src/sysimage/create_sysimage.jl
}

repl() {
  julia
}

cmd="${1:-repl}"
shift || true
$cmd "$@"
