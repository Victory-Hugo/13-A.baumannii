#!/bin/bash

INPUT_DIR="/data_ssd3/7_luolintao_Baoman/1-Assemble/NCBI_Origin/毒力因子"
OUT_DIR="/data_ssd3/7_luolintao_Baoman/1-Assemble/NCBI_Origin/毒力因子/阈值"
PYTHON_SCRIPT="/home/luolintao/0_Github/13-A.baumannii/4-注释/4-Virulence/python/3-筛选diamond.py"

python3 "$PYTHON_SCRIPT"  \
    "$INPUT_DIR" \
    "$OUT_DIR"