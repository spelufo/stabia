#!/usr/bin/env bash

set -e

export VESUVIUS_DATA_DIR="$(pwd)/../data"
export VESUVIUS_SERVER_AUTH='registeredusers:only'

julia() {
  command julia --project=. "$@"
}

repl() {
  julia
}

cmd="${1:-repl}"
shift || true
$cmd "$@"
