#!/usr/bin/env bash

set -e

export VESUVIUS_DATA_DIR="$(pwd)/../data"
export VESUVIUS_SERVER_AUTH='registeredusers:only'

julia() {
  # Leave one thread unused.
  # Otherwise sometimes when I run something it freezes the machine.
  export JULIA_NUM_THREADS=11
  command julia --project=. "$@"
}

repl() {
  julia
}

cmd="${1:-repl}"
shift || true
$cmd "$@"
