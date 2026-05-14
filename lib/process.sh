#!/usr/bin/env bash

_resolve_imppath() {
  local imppath="$1" dir="$2" abs
  if [[ "$imppath" == ".." || "$imppath" == "../"* ]]; then
    canonicalize "$dir/$imppath"; return 0
  fi
  if [[ "$imppath" == "." || "$imppath" == "./"* ]]; then
    (( ${INCLUDE_SIBLINGS:-0} )) || return 1
    canonicalize "$dir/$imppath"; return 0
  fi
  if abs="$(expand_alias "$imppath")"; then printf '%s' "$abs"; return 0; fi
  if abs="$(expand_stale_alias "$imppath")"; then printf '%s' "$abs"; return 0; fi
  return 1
}

_apply_patterns() {
  (( ${#EXTRA_PATTERNS[@]} )) || return 0
  local pat match imppath abspath replacement new_match
  for pat in "${EXTRA_PATTERNS[@]}"; do
    if [[ "$line" =~ $pat ]]; then
      match="${BASH_REMATCH[0]}"
      imppath="${BASH_REMATCH[1]}"
      [[ -z "$imppath" ]] && continue
      if abspath="$(_resolve_imppath "$imppath" "$file_dir")"; then
        if replacement="$(best_alias "$abspath")"; then
          if [[ "$replacement" != "$imppath" ]]; then
            new_match="${match/$imppath/$replacement}"
            line="${line/$match/$new_match}"
            changed=1
          fi
        fi
      fi
    fi
  done
}

process_file() {
  local file="$1"
  local file_dir
  file_dir="$(dirname "$file")"
  local changed=0
  local line
  local line_num=0
  local stopped_at=0
  local -a buffer=()

  while IFS= read -r line || [[ -n "$line" ]]; do
    line_num=$((line_num + 1))

    local trimmed="${line#"${line%%[![:space:]]*}"}"

    if [[ -z "$trimmed" ]]; then
      buffer+=("$line")
      continue
    fi

    if [[ "$trimmed" != import* ]]; then
      _apply_patterns
      buffer+=("$line")
      if (( ${FULL_SCAN:-0} || ${#EXTRA_PATTERNS[@]} > 0 )); then
        continue
      fi
      stopped_at=$line_num
      break
    fi

    # <prefix-up-to-quote><module-path><closing-quote><rest>
    if [[ "$line" =~ ^([[:space:]]*import[^\'\"]*[\'\"])([^\'\"]+)([\'\"])(.*)$ ]]; then
      local prefix="${BASH_REMATCH[1]}"
      local imppath="${BASH_REMATCH[2]}"
      local quote="${BASH_REMATCH[3]}"
      local rest="${BASH_REMATCH[4]}"
      local abspath replacement
      if abspath="$(_resolve_imppath "$imppath" "$file_dir")"; then
        if replacement="$(best_alias "$abspath")"; then
          if [[ "$replacement" != "$imppath" ]]; then
            line="${prefix}${replacement}${quote}${rest}"
            changed=1
          fi
        fi
      fi
    fi

    buffer+=("$line")
  done < "$file"

  if (( ! changed )); then
    return 0
  fi

  local tmp
  tmp="$(mktemp)"
  if (( ${#buffer[@]} )); then
    printf '%s\n' "${buffer[@]}" >> "$tmp"
  fi
  if (( stopped_at > 0 )); then
    tail -n +$((stopped_at + 1)) "$file" >> "$tmp"
  fi

  # Preserve original trailing-newline state.
  if [[ -s "$file" && "$(tail -c1 "$file" | wc -l | tr -d ' ')" -eq 0 ]]; then
    perl -i -pe 'chomp if eof' "$tmp"
  fi

  mv "$tmp" "$file"
  printf 'Updated: %s\n' "${file#"$ROOT_DIR/"}"
}
