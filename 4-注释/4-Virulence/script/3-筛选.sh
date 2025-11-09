#!/bin/bash

INPUT_DIR="/data_raid/7_luolintao/1_Baoman/1-Assemble/NCBI_Sequence/毒力因子"
OUT_DIR="/data_raid/7_luolintao/1_Baoman/1-Assemble/NCBI_Sequence/毒力因子/阈值"
PYTHON_SCRIPT="/home/luolintao/0_Github/13-A.baumannii/4-注释/4-Virulence/python/3-筛选diamond.py"

python3 "$PYTHON_SCRIPT"  \
    "$INPUT_DIR" \
    "$OUT_DIR"