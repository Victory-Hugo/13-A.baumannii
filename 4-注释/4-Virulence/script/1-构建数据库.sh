#!/usr/bin/env bash
set -euo pipefail
# * 建立数据库
VFDB_DIR="/mnt/f/OneDrive/文档（科研）/脚本/Download/13-A.baumannii/4-注释/4-Virulence/data"
OUT_DIR="${VFDB_DIR}"

A_PRO="${VFDB_DIR}/VFDB_setA_pro.fas"
B_PRO="${VFDB_DIR}/VFDB_setB_pro.fas"
COMBINED="${OUT_DIR}/VFDB_2022_pro_combined.faa"
DB_PREFIX="${OUT_DIR}/VFDB_2022_pro_combined"

# 1) 合并 setA + setB 为一个蛋白 FASTA
cat "$A_PRO" "$B_PRO" > "$COMBINED"

# 2) 构建 BLAST 蛋白数据库
makeblastdb -in "$COMBINED" -dbtype prot -out "$DB_PREFIX"

echo "✅ VFDB 蛋白数据库就绪：${DB_PREFIX}.*"
