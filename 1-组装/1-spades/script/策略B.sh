#!/bin/bash
set -euo pipefail

# === 策略B：SPAdes + 覆盖度过滤 ===
# 路径设置（保持一致）
raw_data_dir="/mnt/c/Users/Administrator/Desktop/ERR197551"
read1="${raw_data_dir}/ERR197551_1.fastq.gz"
read2="${raw_data_dir}/ERR197551_2.fastq.gz"

# 资源参数
THREADS=16
MEMORY=16

# 分析目录（独立）
analysis_dir="/mnt/c/Users/Administrator/Desktop/ERR197551_strategyB"
mkdir -p "$analysis_dir"
cd "$analysis_dir"

echo "📁 策略B分析目录: $analysis_dir"

echo ""
echo "=== 步骤1: 序列去重和过滤（BBTools 可选） ==="
if command -v bbduk.sh &>/dev/null; then
    echo "🔧 使用 BBTools (bbduk.sh) 进行数据清理..."
    bbduk.sh \
        in1="$read1" \
        in2="$read2" \
        out1=cleaned_1.fastq.gz \
        out2=cleaned_2.fastq.gz \
        threads="$THREADS"
    echo "✅ 数据清理完成"
    cleaned_read1="cleaned_1.fastq.gz"
    cleaned_read2="cleaned_2.fastq.gz"
else
    echo "⚠️  BBTools 未安装，使用原始数据"
    cleaned_read1="$read1"
    cleaned_read2="$read2"
fi

echo ""
echo "=== 步骤2: 组装 - 策略B（SPAdes + 覆盖度阈值） ==="
if ! command -v spades.py &>/dev/null; then
    echo "❌ 未找到 spades.py，请先安装 SPAdes"
    exit 1
fi

mkdir -p strategyB_coverage
echo "🔧 运行 SPAdes（--isolate, --cov-cutoff 15, k=21,33,55）..."
spades.py \
    --isolate \
    --pe1-1 "$cleaned_read1" \
    --pe1-2 "$cleaned_read2" \
    --threads "$THREADS" \
    --memory "$MEMORY" \
    --cov-cutoff 15 \
    -k 21,33,55 \
    -o strategyB_coverage

echo "✅ 策略B完成。输出：strategyB_coverage/contigs.fasta"
