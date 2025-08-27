#!/usr/bin/env bash
set -euo pipefail
# # * 建立 DIAMOND 数据库
# # * 更快的diamond方法
VFDB_DIR="/mnt/f/OneDrive/文档（科研）/脚本/Download/13-A.baumannii/4-注释/5-LiNM2023/data"
OUT_DIR="${VFDB_DIR}"

A_PRO="${VFDB_DIR}/VFDB_setA_pro.fas"
B_PRO="${VFDB_DIR}/VFDB_setB_pro.fas"
COMBINED="${OUT_DIR}/biocide_resistance.translated.faa"
DB_PREFIX="${OUT_DIR}/biocide_resistance.translated.dmnd"


# 1) 构建 DIAMOND 蛋白数据库
diamond makedb --in "$COMBINED" -d "$DB_PREFIX"

echo "✅ VFDB DIAMOND 数据库就绪：${DB_PREFIX}"


