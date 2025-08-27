#!/bin/bash
# 使用vsearch对剩余毒力因子进行聚类分析
# 阈值：<99.5% identity
# 保留样本ID和基因ID用于后期追踪

# 设置路径
INPUT_DIR="/mnt/d/1-鲍曼菌/毒力因子其他"
TEMP_DIR="${INPUT_DIR}/vsearch_clustering/"
FINAL_DIR="${INPUT_DIR}/vsearch_clustering_final/"
SCRIPT_DIR="/mnt/f/OneDrive/文档（科研）/脚本/Download/13-A.baumannii/4-注释/7-剩余毒力因子/python"

# 创建输出目录
mkdir -p "$TEMP_DIR"
mkdir -p "$FINAL_DIR"
# 检查vsearch是否安装
if ! command -v vsearch &> /dev/null; then
    echo "错误: vsearch未安装或不在PATH中"
    echo "请先安装vsearch: conda install -c bioconda vsearch"
    exit 1
fi

echo "开始处理剩余毒力因子聚类分析..."
echo "输入目录: $INPUT_DIR"
echo "输出目录: $TEMP_DIR"

# 第一步：合并所有样本的FASTA文件，并添加样本来源信息
echo "步骤1: 合并FASTA文件并添加样本信息..."
python3 "$SCRIPT_DIR/2-merge-fasta.py" "$INPUT_DIR" "$TEMP_DIR/all_genes_with_sample_info.fasta"

# 第二步：使用vsearch进行聚类
echo "步骤2: 使用vsearch进行聚类 (identity < 99.5%)..."
vsearch --cluster_fast "$TEMP_DIR/all_genes_with_sample_info.fasta" \
        --id 0.995 \
        --centroids "$TEMP_DIR/centroids.fasta" \
        --clusters "$TEMP_DIR/cluster_" \
        --uc "$TEMP_DIR/clustering_results.uc" \
        --consout "$TEMP_DIR/consensus.fasta" \
        --msaout "$TEMP_DIR/alignment.fasta" \
        --threads 16

# 第三步：解析聚类结果并生成追踪表
echo "步骤3: 解析聚类结果并生成追踪表..."
python3 "$SCRIPT_DIR/3-处理聚类结果.py" "$TEMP_DIR/clustering_results.uc" "$TEMP_DIR"

echo "聚类分析完成！"
echo "结果文件："
echo "  - 聚类中心序列: $TEMP_DIR/centroids.fasta"
echo "  - 聚类结果详情: $TEMP_DIR/clustering_results.uc"
echo "  - 样本基因追踪表: $TEMP_DIR/gene_sample_tracking.tsv"
echo "  - 聚类统计信息: $TEMP_DIR/cluster_statistics.tsv"

mv "$TEMP_DIR/centroids.fasta" "$FINAL_DIR/"
mv "$TEMP_DIR/clustering_results.uc" "$FINAL_DIR/"
mv "$TEMP_DIR/gene_sample_tracking.tsv" "$FINAL_DIR/"
mv "$TEMP_DIR/cluster_statistics.tsv" "$FINAL_DIR/"

rm -rf "${TEMP_DIR}"