#!/usr/bin/env bash
# Discovery + parsing of tsconfig*.json.
#
# Public API:
#   list_tsconfig_candidates DIR
#       — prints every tsconfig*.json found by walking from DIR upward,
#         shortest filename first at each level.
#
#   parse_tsconfig FILE
#       — prints "alias|absolute-target" lines for compilerOptions.paths,
#         sorted longest-target-first. Prints nothing if `paths` is absent.
#         Handles tsconfig's JSONC dialect (comments, trailing commas).
#
#   discover_aliases STARTDIR [EXPLICIT_TSCONFIG]
#       — tries candidates in order; the first one yielding aliases wins.
#         Sets globals:
#           CHOSEN_TSCONFIG   path of the chosen tsconfig (empty if none)
#           ALIASES_RAW       parse_tsconfig output (empty if none yielded)

list_tsconfig_candidates() {
  local dir="$1"
  while [[ -n "$dir" && "$dir" != "/" ]]; do
    shopt -s nullglob
    local matches=("$dir"/tsconfig*.json)
    shopt -u nullglob
    if (( ${#matches[@]} )); then
      printf '%s\n' "${matches[@]}" | awk '{ print length, $0 }' | sort -n | cut -d' ' -f2-
    fi
    dir="$(dirname "$dir")"
  done
}

parse_tsconfig() {
  local cfg="$1"
  perl - "$cfg" <<'PERL'
use strict;
use warnings;
use File::Spec;

my $cfg = shift @ARGV;
open(my $fh, '<', $cfg) or die "open $cfg: $!";
local $/;
my $raw = <$fh>;
close $fh;

# Strip JSONC comments — but only outside of string literals, so that
# `*/` inside `"**/*.feature"` or `//` inside a URL doesn't false-match.
# The alternation captures a full string in $1; comments capture nothing
# and get replaced with the empty string.
$raw =~ s{
    ( "(?: [^"\\] | \\. )* " )   # $1 = a complete "…" string
  | /\* .*? \*/                  # block comment
  | // [^\n]*                    # line comment
}{ defined $1 ? $1 : "" }gsxe;
# Strip trailing commas before } or ].
$raw =~ s/,(\s*[\}\]])/$1/g;

my ($base_url) = $raw =~ /"baseUrl"\s*:\s*"([^"]+)"/;
$base_url = '.' unless defined $base_url;

my $cfg_dir = (File::Spec->splitpath($cfg))[1];
$cfg_dir =~ s{/$}{};
my $base_abs = File::Spec->rel2abs($base_url, $cfg_dir);

# paths block: values are arrays of strings, so non-greedy `.*?` is safe.
my ($block) = $raw =~ /"paths"\s*:\s*\{(.*?)\}/s;
exit 0 unless defined $block;

my @entries;
while ($block =~ /"([^"]+)"\s*:\s*\[\s*"([^"]+)"/g) {
  my ($alias, $target) = ($1, $2);
  $alias  =~ s{/\*$}{};
  $target =~ s{/\*$}{};
  my $abs = File::Spec->rel2abs($target, $base_abs);
  push @entries, [$alias, $abs];
}

@entries = sort { length($b->[1]) <=> length($a->[1]) } @entries;
print "$_->[0]|$_->[1]\n" for @entries;
PERL
}

discover_aliases() {
  local startdir="$1"
  local explicit="${2:-}"
  CHOSEN_TSCONFIG=""
  ALIASES_RAW=""

  if [[ -n "$explicit" ]]; then
    if [[ ! -f "$explicit" ]]; then
      echo "Error: $explicit does not exist" >&2
      return 1
    fi
    ALIASES_RAW="$(parse_tsconfig "$explicit")"
    CHOSEN_TSCONFIG="$explicit"
    return 0
  fi

  local candidate parsed
  while IFS= read -r candidate; do
    [[ -n "$candidate" ]] || continue
    parsed="$(parse_tsconfig "$candidate")"
    if [[ -n "$parsed" ]]; then
      ALIASES_RAW="$parsed"
      CHOSEN_TSCONFIG="$candidate"
      return 0
    fi
    # Track the first candidate seen so the caller can distinguish
    # "none found" from "found but none had paths".
    [[ -z "$CHOSEN_TSCONFIG" ]] && CHOSEN_TSCONFIG="$candidate"
  done < <(list_tsconfig_candidates "$startdir")

  # If we exit with CHOSEN_TSCONFIG set but ALIASES_RAW empty, caller knows
  # that candidates existed but none declared compilerOptions.paths.
  return 0
}
