#!/usr/bin/env bash

set -e

cd logs/recon_15/acvd

for f in $(lines ../cleaned/turn_??_h?.ply); do
  of="${f##*/}"
  of="${of%.ply}_acvd.ply"
  ACVD "$f" 400000 1 -s 2 -m 1 -of "$of" | tee "$of.log"
done
