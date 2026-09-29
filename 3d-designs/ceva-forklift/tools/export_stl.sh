#!/usr/bin/env bash
# Export every print part of ceva_forklift.scad to stl/ (print orientation).
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p stl
parts="body_white body_black body_red mast_black
       wheelF_black wheelF_white wheelR_black wheelR_white
       load_kraft load_navy load_red"
for p in $parts; do
    echo "== $p"
    openscad -q -D "part=\"$p\"" -o "stl/$p.stl" ceva_forklift.scad &
done
wait
ls -l stl
