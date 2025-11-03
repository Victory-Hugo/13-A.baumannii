#!/bin/bash
#todo 使用之前请先切换到conda环境安装prokka
#todo conda install prokka

# 定义输入和输出目录
INPUT_DIR="/data_raid/7_luolintao/1_Baoman/1-Assemble/NCBI_Sequence/fasta"
OUTPUT_DIR="/data_raid/7_luolintao/1_Baoman/1-Assemble/NCBI_Sequence/prokka"

# 创建输出目录（如果不存在）
mkdir -p "$OUTPUT_DIR"

# 定义处理单个fasta文件的函数
process_fasta() {
    local fasta_file="$1"
    local basename=$(basename "$fasta_file" .fasta)
    local outdir="$OUTPUT_DIR/$basename"
    
    echo "开始处理: $basename"
    
    prokka \
        --outdir "$outdir" \
        --prefix "$basename" \
        --force \
        --kingdom Bacteria \
        --genus Acinetobacter \
        --species baumannii \
        --strain "$basename" \
        --cpus 4 \
        "$fasta_file"
    
    echo "完成处理: $basename"
}

# 导出函数以便parallel使用
export -f process_fasta
export OUTPUT_DIR

# 使用parallel并行处理所有fasta文件
find "$INPUT_DIR" -name "*.fasta" -type f | parallel --bar -j 8 process_fasta

echo "所有文件处理完成！"
python3 /home/luolintao/test_mail.py "4-注释/1-prokka/script/2-prokka.sh任务完成通知" "<p>4-注释/1-prokka/script/2-prokka.sh分析已完成，请查看结果目录。</p>"
echo "已发送任务完成通知邮件。"