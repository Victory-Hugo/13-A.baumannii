#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  3-quality-exam.sh -i <sai_list.txt> -b <bam_dir> -o <quality_dir> [-t <threads>] [-l <log>]
Note:
  sai_list.txt each line: <sai1> <sai2> <fq1> <fq2>
EOF
}

die() {
  echo "Error: $*" >&2
  exit 1
}

input_list=""
bam_dir=""
out_dir=""
threads="1"
log=""

while getopts ":i:b:o:t:l:h" opt; do
  case "$opt" in
    i) input_list="$OPTARG" ;;
    b) bam_dir="$OPTARG" ;;
    o) out_dir="$OPTARG" ;;
    t) threads="$OPTARG" ;;
    l) log="$OPTARG" ;;
    h) usage; exit 0 ;;
    *) usage; exit 1 ;;
  esac
done

[ -n "$input_list" ] || die "missing -i <sai_list.txt>"
[ -n "$bam_dir" ] || die "missing -b <bam_dir>"
[ -n "$out_dir" ] || die "missing -o <quality_dir>"

[ -f "$input_list" ] || die "input list not found: $input_list"
[ -d "$bam_dir" ] || die "bam dir not found: $bam_dir"

command -v samtools >/dev/null 2>&1 || die "samtools not found in PATH"

mkdir -p "$out_dir"
summary="$out_dir/quality_summary.tsv"

if [ -z "$log" ]; then
  log="$out_dir/quality_exam.log"
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

append_summary() {
  local sample bam mapped mean_depth
  sample="$1"
  bam="$2"
  mapped="$3"
  mean_depth="$4"
  {
    flock 200
    if [ ! -s "$summary" ]; then
      printf "sample\tbam\tmapped_percent\tmean_depth\n" >> "$summary"
    fi
    printf "%s\t%s\t%s\t%s\n" "$sample" "$bam" "$mapped" "$mean_depth" >> "$summary"
  } 200>"$summary.lock"
}

run_one() {
  local line sai1 sai2 fq1 fq2 prefix bam flagstat_out depth_out mapped mean_depth
  line="$1"
  read -r sai1 sai2 fq1 fq2 <<<"$line"
  [ -n "$fq1" ] || die "missing fq1 in line: $line"
  prefix="$(strip_prefix "$fq1")"
  bam="$bam_dir/${prefix}.sorted.bam"
  [ -f "$bam" ] || die "bam not found: $bam"

  flagstat_out="$out_dir/${prefix}.flagstat.txt"
  depth_out="$out_dir/${prefix}.depth.txt"

  samtools flagstat "$bam" > "$flagstat_out"
  mapped="$(awk '/ mapped \(/ {gsub(/[()%]/,"",$5); print $5; exit}' "$flagstat_out")"
  if [ -z "$mapped" ]; then
    mapped="NA"
  fi

  mean_depth="$(samtools depth "$bam" | awk '{sum+=$3} END {if (NR>0) print sum/NR; else print 0}')"
  printf "%s\n" "$mean_depth" > "$depth_out"

  append_summary "$prefix" "$bam" "$mapped" "$mean_depth"

  {
    flock 200
    printf '%s\n' "$line" >> "$log"
  } 200>"$log.lock"
}

export -f strip_prefix append_summary run_one
export bam_dir out_dir summary log

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
