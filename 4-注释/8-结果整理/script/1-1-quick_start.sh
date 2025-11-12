#!/bin/bash
# 一键运行三类注释结果的格式转换脚本
set -euo pipefail
# 输入路径：
# 1-注释汇总/input/毒力因子_合并.csv
# 1-注释汇总/input/抗生素耐药_合并.csv
# 1-注释汇总/input/生物杀灭抵抗_合并.csv
SCRIPT_DIR="/mnt/f/OneDrive/文档（科研）/脚本/Download/13-A.baumannii/4-注释/8-结果整理/script"
INPUT_DIR="/mnt/d/1-ABaumannii/1-注释汇总/input"
OUTPUT_DIR="/mnt/d/1-ABaumannii/1-注释汇总/output"

DETAILED_RESULT="YES"
BLUE='\033[0;34m'
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

log() {
    local color="$1"; shift
    echo -e "${color}$*${NC}"
}

run_conversion() {
    local label="$1"
    local script="$2"
    local input_file="$3"
    local output_subdir="$4"
    local full_output="${5:-是}"

    log "$BLUE" "========================================"
    log "$BLUE" "▶ 处理 ${label} 数据"
    log "$BLUE" "========================================"

    if [[ ! -f "$input_file" ]]; then
        log "$RED" "输入文件不存在：$input_file"
        return 1
    fi
    if [[ ! -x "$script" ]]; then
        log "$RED" "脚本不存在或不可执行：$script"
        return 1
    fi

    local target_dir="$OUTPUT_DIR/$output_subdir"
    mkdir -p "$target_dir"
    log "$GREEN" "输出目录：$target_dir"

    log "$BLUE" "运行：python3 $script $input_file $target_dir $full_output"
    python3 "$script" "$input_file" "$target_dir" "$full_output"
    log "$GREEN" "完成 ${label} 数据转换"
}

run_conversion "抗生素耐药" \
    "$SCRIPT_DIR/2-AMR_format_conversion.py" \
    "$INPUT_DIR/抗生素耐药_合并.csv" \
    "抗生素耐药" \
    "${DETAILED_RESULT}"

run_conversion "毒力因子" \
    "$SCRIPT_DIR/2-virulence_format_conversion.py" \
    "$INPUT_DIR/毒力因子_合并.csv" \
    "毒力因子" \
    "${DETAILED_RESULT}"

run_conversion "生物杀灭抵抗" \
    "$SCRIPT_DIR/2-biocide_format_conversion.py" \
    "$INPUT_DIR/生物杀灭抵抗_合并.csv" \
    "生物杀灭抵抗" \
    "${DETAILED_RESULT}"

log "$GREEN" "✅ 全部转换完成，结果位于：$OUTPUT_DIR"
