#!/usr/bin/env bash
# Path canonicalization without requiring the file to exist.
# Equivalent to GNU `realpath -m`, which BSD realpath on macOS lacks.

canonicalize() {
  local p="$1"
  local IFS='/'
  local -a out=()
  for part in $p; do
    case "$part" in
      ""|".") ;;
      "..")
        if (( ${#out[@]} > 0 )); then
          unset 'out[${#out[@]}-1]'
          out=("${out[@]}")
        fi
        ;;
      *) out+=("$part") ;;
    esac
  done
  local result=""
  for part in "${out[@]}"; do
    result="$result/$part"
  done
  printf '%s' "${result:-/}"
}
