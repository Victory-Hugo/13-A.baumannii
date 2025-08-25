#!/bin/bash
set -euo pipefail

# === FastQC 单独质量检查 ===
# 与原脚本保持一致的路径设置
raw_data_dir="/mnt/c/Users/Administrator/Desktop/ERR197551"
read1="${raw_data_dir}/ERR197551_1.fastq.gz"
read2="${raw_data_dir}/ERR197551_2.fastq.gz"

# 输出目录（独立）
analysis_dir="/mnt/c/Users/Administrator/Desktop/ERR197551_fastqc"
mkdir -p "$analysis_dir"
cd "$analysis_dir"

echo "📁 FastQC 分析目录: $analysis_dir"
echo "=== 步骤: 数据质量深度检查（FastQC） ==="

if command -v fastqc &>/dev/null; then
    echo "🔧 运行 FastQC..."
    mkdir -p fastqc_output
    fastqc "$read1" "$read2" -o fastqc_output --threads 16
    echo "✅ FastQC 完成，结果在 fastqc_output/"
else
    echo "⚠️  FastQC 未安装，跳过质量检查"
    exit 1
fi

echo "🏁 FastQC 完成。"

# python3 \
#     /mnt/f/OneDrive/文档（科研）/脚本/Download/13-A.baumannii/0-质控/python/1-FASTQ质控信息提取.py \
#     /mnt/c/Users/Administrator/Desktop/ERR197551_FQ/fastqc_summary.csv \
#     /mnt/c/Users/Administrator/Desktop/ERR197551_FQ/ERR197551_1_fastqc.html \
#     /mnt/c/Users/Administrator/Desktop/ERR197551_FQ/ERR197551_2_fastqc.html

