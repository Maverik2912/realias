#!/usr/bin/env bash

expand_alias() {
  local imppath="$1"
  local entry alias abs
  for entry in "${ALIASES[@]}"; do
    alias="${entry%%|*}"
    abs="${entry#*|}"
    if [[ "$imppath" == "$alias" ]]; then
      printf '%s' "$abs"
      return 0
    fi
    if [[ "$imppath" == "$alias/"* ]]; then
      printf '%s/%s' "$abs" "${imppath#"$alias/"}"
      return 0
    fi
  done
  return 1
}

expand_stale_alias() {
  local imppath="$1"
  local lead="${imppath:0:1}"
  case "$lead" in
    [A-Za-z0-9_./]|'') return 1 ;;
  esac

  local entry alias
  for entry in "${ALIASES[@]}"; do
    alias="${entry%%|*}"
    [[ "${alias:0:1}" == "$lead" ]] && return 1
  done

  local seen="|"
  for entry in "${ALIASES[@]}"; do
    alias="${entry%%|*}"
    local c="${alias:0:1}"
    [[ "$seen" == *"|$c|"* ]] && continue
    seen="$seen$c|"
    local abs
    if abs="$(expand_alias "${c}${imppath:1}")"; then
      printf '%s' "$abs"
      return 0
    fi
  done
  return 1
}

best_alias() {
  local abspath="$1"
  local entry alias abs
  for entry in "${ALIASES[@]}"; do
    alias="${entry%%|*}"
    abs="${entry#*|}"
    if [[ "$abspath" == "$abs" ]]; then
      printf '%s' "$alias"
      return 0
    fi
    if [[ "$abspath" == "$abs/"* ]]; then
      printf '%s/%s' "$alias" "${abspath#"$abs/"}"
      return 0
    fi
  done
  return 1
}
