#!/bin/bash
# Author: BigLin

AMR_OUT_DIR="/data_raid/7_luolintao/1_Baoman/1-Assemble/NCBI_Origin/抗生素耐药"
OUTPUT_FILE="/data_raid/7_luolintao/1_Baoman/1-Assemble/NCBI_Origin/All_Samples_抗生素耐药.csv"
TEMP_COMBINED="${AMR_OUT_DIR}/All_Samples_Antibiotic_Genes.csv"

build_segment() {
    local count=$1
    local char=$2
    printf -v segment '%*s' "$count" ''
    printf '%s' "${segment// /$char}"
}

print_progress() {
    local current=$1
    local total=$2
    local width=40
    local percent=$(( current * 100 / total ))
    local filled=$(( percent * width / 100 ))
    local empty=$(( width - filled ))
    printf '\rProgress [%s%s] %d/%d (%d%%)' "$(build_segment "$filled" '#')" "$(build_segment "$empty" '-')" "$current" "$total" "$percent"
}

cd "$AMR_OUT_DIR" || {
    echo "Unable to access ${AMR_OUT_DIR}" >&2
    exit 1
}

shopt -s nullglob
files=( *.tsv )
total=${#files[@]}
if (( total == 0 )); then
    echo "No .tsv files found in ${AMR_OUT_DIR}."
    shopt -u nullglob
    exit 0
fi

: > "$TEMP_COMBINED"

count=0
header_written=0
print_progress "$count" "$total"
for file in "${files[@]}"; do
    count=$(( count + 1 ))
    file_base="$(basename "$file")"
    if (( header_written == 0 )); then
        awk -v FS='\t' -v OFS=',' -v fname="$file_base" '
            NR==1 { $1 = "filename," $1; print; next }
            { $1 = fname "," $1; print }
        ' "$file" >> "$TEMP_COMBINED"
        header_written=1
    else
        awk -v FS='\t' -v OFS=',' -v fname="$file_base" '
            NR==1 { next }
            { $1 = fname "," $1; print }
        ' "$file" >> "$TEMP_COMBINED"
    fi
    print_progress "$count" "$total"
done
printf '\n'
shopt -u nullglob

mv "$TEMP_COMBINED" "$OUTPUT_FILE"
echo "Output written to ${OUTPUT_FILE}."