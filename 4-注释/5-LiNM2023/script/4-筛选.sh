
#!/usr/bin/env bash

INPUT_DIR="/data_ssd3/7_luolintao_Baoman/1-Assemble/NCBI_Origin/生物杀灭抵抗"
OUT_DIR="/data_ssd3/7_luolintao_Baoman/1-Assemble/NCBI_Origin/生物杀灭抵抗/阈值"
PYTHON_SCRIPT="/home/luolintao/0_Github/13-A.baumannii/4-注释/5-LiNM2023/python/3-筛选diamond.py"

python3 "$PYTHON_SCRIPT"  \
    "$INPUT_DIR" \
    "$OUT_DIR"