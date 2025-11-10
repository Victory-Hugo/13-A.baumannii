#!/bin/bash
# Author: BigLin

YUZHI_DIR="/data_raid/7_luolintao/1_Baoman/1-Assemble/NCBI_Origin/毒力因子/阈值"
TEMP_COMBINED="${YUZHI_DIR}/combined_virulence_data.csv"
OUTPUT_FILE="/data_raid/7_luolintao/1_Baoman/1-Assemble/NCBI_Origin/All_Samples_毒力因子_阈值.csv"

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

cd "$YUZHI_DIR" || {
    echo "Unable to access ${YUZHI_DIR}" >&2
    exit 1
}

shopt -s nullglob
files=( *.txt )
total=${#files[@]}
if (( total == 0 )); then
    echo "No .txt files found in ${YUZHI_DIR}."
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