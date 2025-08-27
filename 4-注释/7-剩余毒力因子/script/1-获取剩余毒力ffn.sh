#!/usr/bin/env bash
# 脚本功能说明：
# 本脚本用于批量处理鲍曼不动杆菌（A. baumannii）注释结果，提取剩余毒力因子相关的 ffn 文件。通过并行方式调用指定的 Python 脚本，对每个样本目录进行处理。

# 主要流程：
# 1. 固定路径设置：定义注释结果目录、荚膜多糖相关目录、输出目录及 Python 脚本路径。
# 2. 环境变量导出：将路径变量导出，供后续 Python 脚本使用。
# 3. 依赖检查：确保已安装 GNU parallel 和 python3。
# 4. 样本目录获取：自动查找注释结果目录下的所有样本子目录。
# 5. 并行处理：使用 GNU parallel 并发调用 Python 脚本，处理每个样本。
# 6. 任务完成提示。

# 参数说明：
# - PROKKA_DIR：prokka 注释结果主目录，每个样本一个子目录。
# - K_DIR：K 荚膜多糖分析结果目录。
# - OCL_DIR：OCL 荚膜多糖分析结果目录。
# - OUTPUT_DIR：毒力因子输出目录。
# - PARALLEL_JOBS：并行处理的任务数。
# - PYTHON_SCRIPT：实际处理的 Python 脚本路径。

# 注意事项：
# - 需提前安装 GNU parallel 和 python3。
# - 各目录路径需根据实际情况修改。
# - Python 脚本需支持以样本名作为参数进行处理。

# /mnt/d/1-鲍曼菌/荚膜多糖/K_locus_results
# ├── ERR1946991_kaptive_results.fna
# ├── ERR1946999_kaptive_results.fna

# /mnt/d/1-鲍曼菌/荚膜多糖/OCL_results
# ├── ERR1946991_kaptive_results.fna
# ├── ERR1946999_kaptive_results.fna

# /mnt/d/1-鲍曼菌/注释prokka
# ├── ERR1946991
# │   ├── ERR1946991.ffn
# └── ERR1946999
#     ├── ERR1946999.ffn

# ========== 固定路径 ==========
PROKKA_DIR="/mnt/d/1-鲍曼菌/注释prokka"
K_DIR="/mnt/d/1-鲍曼菌/荚膜多糖/K_locus_results"
OCL_DIR="/mnt/d/1-鲍曼菌/荚膜多糖/OCL_results"
OUTPUT_DIR="/mnt/d/1-鲍曼菌/毒力因子其他"
PARALLEL_JOBS=2
PYTHON_SCRIPT="/mnt/f/OneDrive/文档（科研）/脚本/Download/13-A.baumannii/4-注释/7-剩余毒力因子/python/1-获取剩余毒力ffn.py"
# =======================================

# 导出环境变量，供 process_one.py 使用
export PROKKA_DIR
export K_DIR
export OCL_DIR
export OUTPUT_DIR

# 检查必需命令
if ! command -v parallel >/dev/null 2>&1; then
  echo "Error: GNU parallel 未安装。请先安装 parallel。"
  exit 2
fi

if ! command -v python3 >/dev/null 2>&1; then
  echo "Error: python3 未找到。"
  exit 3
fi

# 使用 find 获取 PROKKA_DIR 下一级子目录名作为 BASENAME
mapfile -t BASENAMES < <(find "${PROKKA_DIR}" -mindepth 1 -maxdepth 1 -type d -printf '%f\n')

if [ "${#BASENAMES[@]}" -eq 0 ]; then
  echo "未在 ${PROKKA_DIR} 下找到子目录（BASENAME），退出。"
  exit 0
fi

echo "固定路径已加载："
echo "  PROKKA_DIR=${PROKKA_DIR}"
echo "  K_DIR=${K_DIR}"
echo "  OCL_DIR=${OCL_DIR}"
echo "  OUTPUT_DIR=${OUTPUT_DIR}"
echo "并行作业数：${PARALLEL_JOBS}"
echo "找到 ${#BASENAMES[@]} 个样本，开始并行处理..."

printf '%s\n' "${BASENAMES[@]}" |\
     parallel -j "${PARALLEL_JOBS}" --eta \
     python3 "${PYTHON_SCRIPT}" {}

echo "全部任务提交完成。"
