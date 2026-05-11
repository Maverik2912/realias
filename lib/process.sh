#!/usr/bin/env bash
# Per-file rewrite.
#
# Iterates lines from the top of FILE:
#   - empty lines are passed through;
#   - lines starting with `import` are parsed and (if they reference a
#     project path) rewritten to use the most specific alias;
#   - the first non-empty non-import line stops the line-by-line scan;
#     the rest of the file is bulk-copied with `tail` (no per-line work).
#
# The buffered/tail design means we touch at most the import block,
# never the body. And if nothing in the import block actually changed,
# we don't write the file at all.
#
# Depends on:
#   canonicalize, expand_alias, best_alias   (sourced from sibling libs)
#   $ROOT_DIR                                (for pretty-printing output)
#   $INCLUDE_SIBLINGS                        (0 = skip `./` imports,
#                                             1 = rewrite them too)

process_file() {
  local file="$1"
  local file_dir
  file_dir="$(dirname "$file")"
  local changed=0
  local line
  local line_num=0
  local stopped_at=0      # line number where we broke out; 0 = never broke

  # Buffer the processed prefix so we only ever write when there's a change.
  local -a buffer=()

  while IFS= read -r line || [[ -n "$line" ]]; do
    line_num=$((line_num + 1))

    local trimmed="${line#"${line%%[![:space:]]*}"}"

    if [[ -z "$trimmed" ]]; then
      buffer+=("$line")
      continue
    fi

    if [[ "$trimmed" != import* ]]; then
      # First non-import line — stop scanning, the rest will be bulk-copied.
      buffer+=("$line")
      stopped_at=$line_num
      break
    fi

    # Match: <prefix-up-to-quote><module-path><closing-quote><rest>
    if [[ "$line" =~ ^([[:space:]]*import[^\'\"]*[\'\"])([^\'\"]+)([\'\"])(.*)$ ]]; then
      local prefix="${BASH_REMATCH[1]}"
      local imppath="${BASH_REMATCH[2]}"
      local quote="${BASH_REMATCH[3]}"
      local rest="${BASH_REMATCH[4]}"
      local abspath=""

      if [[ "$imppath" == ".." || "$imppath" == "../"* ]]; then
        # Parent-directory import — always a rewrite candidate.
        abspath="$(canonicalize "$file_dir/$imppath")"
      elif [[ "$imppath" == "." || "$imppath" == "./"* ]]; then
        # Same-directory import — only rewrite when explicitly opted in.
        if (( ${INCLUDE_SIBLINGS:-0} )); then
          abspath="$(canonicalize "$file_dir/$imppath")"
        else
          buffer+=("$line")
          continue
        fi
      elif abspath="$(expand_alias "$imppath")"; then
        # Already aliased — expand so we can re-check for a better alias.
        :
      else
        # Bare module (node_modules / builtin) — leave alone.
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

  # Write the (rewritten) prefix, then bulk-copy the untouched remainder.
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
