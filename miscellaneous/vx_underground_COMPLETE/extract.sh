#!/usr/bin/env bash
set -euo pipefail
shopt -s nullglob

out="output.txt"
: > "$out"  # truncate/create

# Find only in current directory (not recursive). Add -maxdepth 1 to be explicit with GNU find.
find . -maxdepth 1 -type f \( -iname '*.jpg' -o -iname '*.jpeg' \) -print0 |
while IFS= read -r -d '' file; do
  exiftool -v5 -- "$file" | grep -F 'UserComment' >> "$out" || true
  echo >> "$out"
done

echo "Wrote results to $out"