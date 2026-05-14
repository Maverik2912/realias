#!/usr/bin/env bash

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
      buffer+=("$line")
      if (( ${FULL_SCAN:-0} )); then
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
      local abspath=""

      if [[ "$imppath" == ".." || "$imppath" == "../"* ]]; then
        abspath="$(canonicalize "$file_dir/$imppath")"
      elif [[ "$imppath" == "." || "$imppath" == "./"* ]]; then
        if (( ${INCLUDE_SIBLINGS:-0} )); then
          abspath="$(canonicalize "$file_dir/$imppath")"
        else
          buffer+=("$line")
          continue
        fi
      elif abspath="$(expand_alias "$imppath")"; then
        :
      elif abspath="$(expand_stale_alias "$imppath")"; then
        :
      else
        buffer+=("$line")
        continue
      fi

      local replacement
      if replacement="$(best_alias "$abspath")"; then
        if [[ "$replacement" != "$imppath" ]]; then
          line="${prefix}${replacement}${quote}${rest}"
          changed=1
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
