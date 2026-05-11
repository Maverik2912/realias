#!/usr/bin/env bash
# Project traversal — invokes process_file on every matching source file
# under $ROOT_DIR, pruning unwanted directories.
#
# Config (env vars, both optional):
#   FILE_EXTS  space-separated extensions   (default: "ts tsx js jsx")
#   SKIP_DIRS  space-separated directory names to prune
#              (default: "node_modules .git")
#
# Depends on: process_file, $ROOT_DIR.

walk_project() {
  local -a file_exts skip_dirs
  read -r -a file_exts <<< "${FILE_EXTS:-ts tsx js jsx}"
  read -r -a skip_dirs <<< "${SKIP_DIRS:-node_modules .git}"

  local -a prune_args=()
  local d
  for d in "${skip_dirs[@]}"; do
    if (( ${#prune_args[@]} )); then prune_args+=(-o); fi
    prune_args+=(-name "$d")
  done

  local -a name_args=()
  local ext
  for ext in "${file_exts[@]}"; do
    if (( ${#name_args[@]} )); then name_args+=(-o); fi
    name_args+=(-name "*.$ext")
  done

  local file
  local scanned=0
  local updated_before=0 updated_after=0
  while IFS= read -r -d '' file; do
    scanned=$((scanned + 1))
    if (( ${VERBOSE:-0} )); then
      printf '[%5d] %s\n' "$scanned" "${file#"$ROOT_DIR/"}"
    elif (( scanned % 100 == 0 )); then
      printf '\rScanned %d files...' "$scanned" >&2
    fi
    process_file "$file"
  done < <(find "$ROOT_DIR" \( "${prune_args[@]}" \) -prune -o \
    -type f \( "${name_args[@]}" \) -print0)

  # Clear the in-place counter when not in verbose mode.
  if ! (( ${VERBOSE:-0} )); then
    printf '\rScanned %d files.    \n' "$scanned" >&2
  fi
}
