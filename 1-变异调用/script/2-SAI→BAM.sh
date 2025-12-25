#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  2-SAI→BAM.sh -r <ref.fa> -i <sai_list.txt> -o <out_dir> [-t <threads>] [-l <log>]
Note:
  sai_list.txt each line: <sai1> <sai2> <fq1> <fq2>
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
[ -n "$input_list" ] || die "missing -i <sai_list.txt>"
[ -n "$out_dir" ] || die "missing -o <out_dir>"

[ -f "$ref" ] || die "ref not found: $ref"
[ -f "$input_list" ] || die "input list not found: $input_list"

command -v bwa >/dev/null 2>&1 || die "bwa not found in PATH"
command -v samtools >/dev/null 2>&1 || die "samtools not found in PATH"

mkdir -p "$out_dir"

if [ -z "$log" ]; then
  log="$out_dir/sai2bam.log"
fi
mkdir -p "$(dirname "$log")"
touch "$log"

strip_prefix() {
  local name
  name="$(basename "$1")"
  name="${name%.fastq.gz}"
  name="${name%.fq.gz}"
  name="${name%.fastq}"
  name="${name%.fq}"
  name="${name%_1}"
  name="${name%_2}"
  echo "$name"
}

run_one() {
  local line sai1 sai2 fq1 fq2 prefix out
  line="$1"
  read -r sai1 sai2 fq1 fq2 <<<"$line"
  [ -n "$sai1" ] || die "missing sai1 in line: $line"
  [ -n "$sai2" ] || die "missing sai2 in line: $line"
  [ -n "$fq1" ] || die "missing fq1 in line: $line"
  [ -n "$fq2" ] || die "missing fq2 in line: $line"
  [ -f "$sai1" ] || die "sai1 not found: $sai1"
  [ -f "$sai2" ] || die "sai2 not found: $sai2"
  [ -f "$fq1" ] || die "fq1 not found: $fq1"
  [ -f "$fq2" ] || die "fq2 not found: $fq2"

  prefix="$(strip_prefix "$fq1")"
  out="$out_dir/${prefix}.sorted.bam"

  bwa sampe "$ref" "$sai1" "$sai2" "$fq1" "$fq2" \
    | samtools view -bS - \
    | samtools sort -o "$out"

  samtools index "$out"

  {
    flock 200
    printf '%s\n' "$line" >> "$log"
  } 200>"$log.lock"
}

export -f strip_prefix run_one
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
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    run_one "$line"
  done < "$pending"
else
  command -v parallel >/dev/null 2>&1 || die "parallel not found in PATH"
  parallel -j "$threads" --line-buffer run_one :::: "$pending"
fi

rm -f "$pending"
