#!/usr/bin/env bash
# 批量并行注释脚本
# 功能：
#   - 扫描 /mnt/d/1-鲍曼菌/组装完成/ 下的 fasta/fa/fna
#   - 为每个输入文件在 /mnt/d/1-鲍曼菌/注释prokka/<basename>/ 下生成注释结果
#   - 使用 GNU parallel 并行运行 prokka
#
# 先决条件：
#   conda activate 你的prokka环境
#   conda install -c bioconda prokka parallel
#
# 可调参数（环境变量方式传入）：
#   PER_JOB_CPUS: 每个 prokka 任务使用的线程数（默认 4）
#   KINGDOM/GENUS/SPECIES: 物种信息（默认 Bacteria / Acinetobacter / baumannii）
#
# 用法：
#   bash run_prokka_parallel.sh

set -euo pipefail

# 输入与输出目录（如需调整，改这两行）
INPUT_DIR="/mnt/d/1-鲍曼菌/组装完成"
OUTPUT_ROOT="/mnt/d/1-鲍曼菌/注释prokka"

# 物种参数（可按需改/用环境变量覆盖）
KINGDOM="${KINGDOM:-Bacteria}"
GENUS="${GENUS:-Acinetobacter}"
SPECIES="${SPECIES:-baumannii}"

# 每个任务使用多少 CPU
PER_JOB_CPUS="${PER_JOB_CPUS:-4}"

# 计算并发任务数：总核数 / 每任务核数（至少 1）
if command -v nproc >/dev/null 2>&1; then
  TOTAL_CPUS="$(nproc)"
else
  # Mac 或其他系统兜底
  TOTAL_CPUS="$(getconf _NPROCESSORS_ONLN 2>/dev/null || echo 4)"
fi
if ! [[ "$TOTAL_CPUS" =~ ^[0-9]+$ ]]; then TOTAL_CPUS=4; fi
if ! [[ "$PER_JOB_CPUS" =~ ^[0-9]+$ ]]; then PER_JOB_CPUS=4; fi

JOBS=$(( TOTAL_CPUS / PER_JOB_CPUS ))
if [ "$JOBS" -lt 1 ]; then JOBS=1; fi

echo "🧬 输入目录: $INPUT_DIR"
echo "📁 输出根目录: $OUTPUT_ROOT"
echo "🔢 总核数: $TOTAL_CPUS, 每任务核数: $PER_JOB_CPUS, 并发任务数: $JOBS"
echo "🌱 物种: $KINGDOM / $GENUS / $SPECIES"
echo

mkdir -p "$OUTPUT_ROOT"

annotate_one() {
  local f="$1"
  # 处理可能包含空格/中文路径的文件名，basename 提取基本名
  local filename
  filename="$(basename "$f")"
  local ext="${filename##*.}"
  local base="${filename%.*}"

  local outdir="$OUTPUT_ROOT/$base"
  mkdir -p "$outdir"

  echo "🔄 正在注释: $f -> $outdir"

  # 运行 prokka
  prokka \
    --outdir "$outdir" \
    --prefix "$base" \
    --force \
    --kingdom "$KINGDOM" \
    --genus "$GENUS" \
    --species "$SPECIES" \
    --strain "$base" \
    --cpus "$PER_JOB_CPUS" \
    "$f"

  echo "✅ 完成: $base"
}

export -f annotate_one
export OUTPUT_ROOT PER_JOB_CPUS KINGDOM GENUS SPECIES

# 收集输入文件并并行执行（0 结尾分隔，避免空格/中文路径问题）
find "$INPUT_DIR" -maxdepth 1 -type f \( -iname "*.fasta" -o -iname "*.fa" -o -iname "*.fna" \) -print0 \
  | parallel -0 -P "$JOBS" annotate_one {}

echo
echo "🎉 全部完成。结果已生成在: $OUTPUT_ROOT"
