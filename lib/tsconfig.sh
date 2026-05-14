#!/usr/bin/env bash

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

# Strip JSONC comments outside string literals so `*/` in "**/*.feature"
# or `//` in a URL doesn't false-match.
$raw =~ s{
    ( "(?: [^"\\] | \\. )* " )
  | /\* .*? \*/
  | // [^\n]*
}{ defined $1 ? $1 : "" }gsxe;
$raw =~ s/,(\s*[\}\]])/$1/g;

my ($base_url) = $raw =~ /"baseUrl"\s*:\s*"([^"]+)"/;
$base_url = '.' unless defined $base_url;

my $cfg_dir = (File::Spec->splitpath($cfg))[1];
$cfg_dir =~ s{/$}{};
my $base_abs = File::Spec->rel2abs($base_url, $cfg_dir);

# non-greedy `.*?` is safe because path values are string arrays, no nested braces.
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
    # First candidate seen — lets caller distinguish "none found" from "found but no paths".
    [[ -z "$CHOSEN_TSCONFIG" ]] && CHOSEN_TSCONFIG="$candidate"
  done < <(list_tsconfig_candidates "$startdir")

  return 0
}
