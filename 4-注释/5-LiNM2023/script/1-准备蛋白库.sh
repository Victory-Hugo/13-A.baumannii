#!/bin/bash
set -euo pipefail

BASE="/mnt/f/OneDrive/文档（科研）/脚本/Download/13-A.baumannii/4-注释/5-LiNM2023"
CONF="$BASE/conf"
DATA="$BASE/data"

# 1. 从 loci_tag.txt 获取对应 GFF 行
grep -F -f "$CONF/loci_tag.txt" "$DATA/GCF_900088705.1.gff" > "$CONF/loci_tag_gff.txt"

# 2. 提取 locus_tag 及相关信息
awk -F'\t' '{print $9}' "$CONF/loci_tag_gff.txt" \
  | awk -F';locus_tag=' '{print $2}' \
  | awk -F';' -v OFS='\t' '{print $1,$2,$3,$4,$5}' \
  > "$CONF/loci_tag_gff_trim.txt"

# 3. 提取唯一 locus_tag ID
awk -F'\t' '{print $9}' "$CONF/loci_tag_gff.txt" \
  | awk -F';locus_tag=' '{print $2}' \
  | awk -F';' '{print $1}' \
  | sort -u \
  > "$CONF/loci_tag_gff_trim_ID.txt"

# 4. 根据 ID 提取 fasta 条目
awk -v idfile="$CONF/loci_tag_gff_trim_ID.txt" '
BEGIN {
    while((getline < idfile) > 0) {
        ids[$1]=1
    }
}
# header 行：检查是否包含目标 ID
/^>/ {
    keep=0
    for(id in ids) {
        if (index($0,id) > 0) { keep=1; break }
    }
}
# keep=1 的记录输出（header+序列）
keep
' "$DATA/GCF_900088705.1_CDS.fna" > "$DATA/biocide_resistance.protein.fna"

seqkit translate \
  --frame 1 \
  -o "$DATA/biocide_resistance.translated.faa" \
  "$DATA/biocide_resistance.protein.fna"