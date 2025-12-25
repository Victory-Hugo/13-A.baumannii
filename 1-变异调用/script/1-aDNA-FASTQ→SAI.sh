#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  1-aDNA-FASTQ→SAI.sh -r <ref.fa> -i <input_list.txt> -o <out_dir> [-t <threads>] [-l <log>]
EOF
}

die() {
  echo "Error: $*" >&2
  exit 1
}

ref=""
input_list=""
out_dir=""
threads="1"
log=""

while getopts ":r:i:o:t:l:h" opt; do
  case "$opt" in
    r) ref="$OPTARG" ;;
    i) input_list="$OPTARG" ;;
    o) out_dir="$OPTARG" ;;
    t) threads="$OPTARG" ;;
    l) log="$OPTARG" ;;
    h) usage; exit 0 ;;
    *) usage; exit 1 ;;
  esac
done

[ -n "$ref" ] || die "missing -r <ref.fa>"
[ -n "$input_list" ] || die "missing -i <input_list.txt>"
[ -n "$out_dir" ] || die "missing -o <out_dir>"

[ -f "$ref" ] || die "ref not found: $ref"
[ -f "$input_list" ] || die "input list not found: $input_list"

command -v bwa >/dev/null 2>&1 || die "bwa not found in PATH"

mkdir -p "$out_dir"

if [ -z "$log" ]; then
  log="$out_dir/fastq2sai.log"
fi
mkdir -p "$(dirname "$log")"
touch "$log"

strip_ext() {
  local name
  name="$(basename "$1")"
  name="${name%.fastq.gz}"
  name="${name%.fq.gz}"
  name="${name%.fastq}"
  name="${name%.fq}"
  echo "$name"
}

run_one() {
  local fq out
  fq="$1"
  out="$out_dir/$(strip_ext "$fq").sai"
  bwa aln -l 1024 -n 0.01 -o 2 "$ref" "$fq" > "$out"
  {
    flock 200
    printf '%s\n' "$fq" >> "$log"
  } 200>"$log.lock"
}

export -f strip_ext run_one
export ref out_dir log

bwa_index_missing() {
  local base
  base="$1"
  [ ! -f "${base}.bwt" ] || [ ! -f "${base}.sa" ] || [ ! -f "${base}.pac" ] || [ ! -f "${base}.ann" ] || [ ! -f "${base}.amb" ]
}

if bwa_index_missing "$ref"; then
  bwa index "$ref"
fi

pending="$(mktemp)"
if [ -s "$log" ]; then
  awk 'NR==FNR{done[$0]=1; next} !done[$0]' "$log" "$input_list" > "$pending"
else
  cp "$input_list" "$pending"
fi

if [ "$threads" -le 1 ]; then
  while IFS= read -r fq; do
    [ -n "$fq" ] || continue
    run_one "$fq"
  done < "$pending"
else
  command -v parallel >/dev/null 2>&1 || die "parallel not found in PATH"
  parallel -j "$threads" --line-buffer run_one :::: "$pending"
fi

rm -f "$pending"
