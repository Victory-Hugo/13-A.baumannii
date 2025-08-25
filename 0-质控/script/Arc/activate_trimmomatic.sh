#!/bin/bash
# Trimmomatic环境激活脚本
# 用法：source activate_trimmomatic.sh

echo "正在激活trimmomatic conda环境..."
source ~/miniconda3/etc/profile.d/conda.sh
conda activate trimmomatic_env

echo "环境已激活！"
echo "Trimmomatic版本：$(trimmomatic -version)"
echo "Adapter文件路径：$CONDA_PREFIX/share/trimmomatic-0.39-2/adapters/"
echo ""
echo "可用的adapter文件："
ls $CONDA_PREFIX/share/trimmomatic-0.39-2/adapters/
echo ""
echo "使用方法："
echo "trimmomatic PE -threads 4 [输入文件] [输出文件] [参数]"
