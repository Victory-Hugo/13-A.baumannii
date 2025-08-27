
#!/usr/bin/env bash

INPUT_DIR="/mnt/d/1-鲍曼菌/生物杀灭抵抗"
OUT_DIR="/mnt/d/1-鲍曼菌/生物杀灭抵抗/阈值"
PYTHON_SCRIPT="/mnt/f/OneDrive/文档（科研）/脚本/Download/13-A.baumannii/4-注释/5-LiNM2023/python/3-筛选diamond.py"

python3 "$PYTHON_SCRIPT"  \
    "$INPUT_DIR" \
    "$OUT_DIR"