#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# 脚本名称: 5-MLST→Grapetree.sh
# 功能描述: 
#   1. 调用 Python 脚本处理 MLST 详细等位基因文件，生成 Grapetree 所需输入文件。
#   2. 使用 Grapetree 工具分别对 Ox 和 Pa 类型的 MLST 结果进行系统发育树构建，
#      并输出为 Newick 格式树文件。
#
# 输入参数:
#   - MLST_FILE: MLST 详细等位基因信息的 CSV 文件路径
#   - OUTPUT_DIR: 输出文件保存目录
#
# 输出文件:
#   - MLST_ST_Ox.tree.nwk: Ox 类型的系统发育树 (Newick 格式)
#   - MLST_ST_Pa.tree.nwk: Pa 类型的系统发育树 (Newick 格式)
#
# 使用方法:
#   直接运行本脚本，无需额外参数。
#
# 依赖环境:
#   - Python3
#   - Grapetree 工具
#
# 作者: 罗林焘
# 日期: 2025年8月26日
# -----------------------------------------------------------------------------


PYTHON_SCRIPT="/mnt/f/OneDrive/文档（科研）/脚本/Download/13-A.baumannii/4-注释/2-MLST/python/5-MLST→Grapetree.py"
MLST_FILE="/mnt/d/1-鲍曼菌/MLST/分型结果/MLST_detailed_alleles.csv"
OUTPUT_DIR="/mnt/d/1-鲍曼菌/MLST/分型结果/"


# # 调用：输入文件 + 输出目录
# python3 "${PYTHON_SCRIPT}" \
#   "${MLST_FILE}" \
#   "${OUTPUT_DIR}"


grapetree -p "${OUTPUT_DIR}/MLST_ST_Ox.txt" \
     --n_proc 8 \
     --heuristic harmonic \
     > "${OUTPUT_DIR}/MLST_ST_Ox.tree.nwk"

grapetree -p "${OUTPUT_DIR}/MLST_ST_Pa.txt" \
     --n_proc 8 \
     --heuristic harmonic \
     > "${OUTPUT_DIR}/MLST_ST_Pa.tree.nwk"