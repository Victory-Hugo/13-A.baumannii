#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  4-damage-exam.sh -r <ref.fa> -i <sai_list.txt> -b <bam_dir> -o <quality_dir> [-t <threads>] [-l <log>]
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
bam_dir=""
out_dir=""
threads="1"
log=""

while getopts ":r:i:b:o:t:l:h" opt; do
  case "$opt" in
    r) ref="$OPTARG" ;;
    i) input_list="$OPTARG" ;;
    b) bam_dir="$OPTARG" ;;
    o) out_dir="$OPTARG" ;;
    t) threads="$OPTARG" ;;
    l) log="$OPTARG" ;;
    h) usage; exit 0 ;;
    *) usage; exit 1 ;;
  esac
done

[ -n "$ref" ] || die "missing -r <ref.fa>"
[ -n "$input_list" ] || die "missing -i <sai_list.txt>"
[ -n "$bam_dir" ] || die "missing -b <bam_dir>"
[ -n "$out_dir" ] || die "missing -o <quality_dir>"

[ -f "$ref" ] || die "ref not found: $ref"
[ -f "$input_list" ] || die "input list not found: $input_list"
[ -d "$bam_dir" ] || die "bam dir not found: $bam_dir"

command -v mapDamage >/dev/null 2>&1 || die "mapDamage not found in PATH"

mkdir -p "$out_dir/damage"

if [ -z "$log" ]; then
  log="$out_dir/damage_exam.log"
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
  local line sai1 sai2 fq1 fq2 prefix bam out
  line="$1"
  read -r sai1 sai2 fq1 fq2 <<<"$line"
  [ -n "$fq1" ] || die "missing fq1 in line: $line"
  prefix="$(strip_prefix "$fq1")"
  bam="$bam_dir/${prefix}.sorted.bam"
  [ -f "$bam" ] || die "bam not found: $bam"

  out="$out_dir/damage/$prefix"
  mkdir -p "$out"

  mapDamage -i "$bam" -r "$ref" --no-stats -d "$out"

  {
    flock 200
    printf '%s\n' "$line" >> "$log"
  } 200>"$log.lock"
}

export -f strip_prefix run_one
export ref bam_dir out_dir log

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
