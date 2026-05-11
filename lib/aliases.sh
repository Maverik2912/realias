#!/usr/bin/env bash
# Alias matching helpers.
#
# Operate on the global ALIASES array, whose entries are "alias|abs"
# (absolute target paths) and MUST be sorted longest-target-first so
# the first prefix-match is the most specific.
#
# Public API:
#   expand_alias IMPORTPATH
#       — if IMPORTPATH starts with a known alias, prints the absolute
#         path it expands to. Otherwise returns non-zero.
#
#   best_alias ABSPATH
#       — prints the most specific alias-form of ABSPATH, or returns
#         non-zero if no alias covers it.

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
