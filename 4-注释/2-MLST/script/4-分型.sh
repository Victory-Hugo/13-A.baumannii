#!/usr/bin/env bash
set -euo pipefail

# === MLST 分型脚本 ===
# 功能：基于BLAST结果进行鲍曼菌ST分型
# 依赖：Python 3.6+, pandas
# 
# 使用方法：
#   ./4-分型.sh [样本名称...]
#   如果不指定样本名称，则自动处理所有样本

# === 配置区 ===
PYTHON_SCRIPT="/mnt/f/OneDrive/文档（科研）/脚本/Download/13-A.baumannii/4-注释/2-MLST/script/4-分型.py"
PROFILES_DIR="/mnt/f/OneDrive/文档（科研）/脚本/Download/13-A.baumannii/4-注释/2-MLST/download"

# 输入输出路径配置
BLAST_RESULTS_DIR="/mnt/d/1-鲍曼菌/MLST"
OUTPUT_DIR="/mnt/d/1-鲍曼菌/MLST/分型结果"

# 质量控制参数
MIN_IDENTITY=95.0
MIN_COVERAGE=90.0

# === 检查依赖 ===
echo "[INFO] 检查运行环境..."

# 检查Python
if ! command -v python3 >/dev/null 2>&1; then
    echo "ERROR: 未找到 python3 命令" >&2
    exit 1
fi

# 检查pandas
# if ! python3 -c "import pandas" >/dev/null 2>&1; then
#     echo "ERROR: Python缺少pandas库，请安装：pip install pandas" >&2
#     echo "      或使用conda：conda install pandas" >&2
#     exit 1
# fi

# 检查文件
if [[ ! -f "${PYTHON_SCRIPT}" ]]; then
    echo "ERROR: Python脚本不存在：${PYTHON_SCRIPT}" >&2
    exit 1
fi

if [[ ! -d "${BLAST_RESULTS_DIR}" ]]; then
    echo "ERROR: BLAST结果目录不存在：${BLAST_RESULTS_DIR}" >&2
    exit 1
fi

if [[ ! -d "${PROFILES_DIR}" ]]; then
    echo "ERROR: MLST配置目录不存在：${PROFILES_DIR}" >&2
    exit 1
fi

# 检查必要的配置文件
OXFORD_PROFILES="${PROFILES_DIR}/Oxford/profiles_oxford.csv"
PASTEUR_PROFILES="${PROFILES_DIR}/Pasteur/profiles_pasteur.csv"

if [[ ! -f "${OXFORD_PROFILES}" ]]; then
    echo "ERROR: Oxford配置文件不存在：${OXFORD_PROFILES}" >&2
    exit 1
fi

if [[ ! -f "${PASTEUR_PROFILES}" ]]; then
    echo "ERROR: Pasteur配置文件不存在：${PASTEUR_PROFILES}" >&2
    exit 1
fi

echo "[INFO] 环境检查通过 ✅"

# === 构建命令参数 ===
ARGS=(
    -i "${BLAST_RESULTS_DIR}"
    -p "${PROFILES_DIR}"
    -o "${OUTPUT_DIR}"
    --min-identity "${MIN_IDENTITY}"
    --min-coverage "${MIN_COVERAGE}"
)

# 如果指定了样本名称，添加到参数中
if [[ $# -gt 0 ]]; then
    ARGS+=(-s "$@")
    echo "[INFO] 指定样本：$*"
else
    echo "[INFO] 将分析所有可用样本"
fi

# === 运行分析 ===
echo "[INFO] 开始MLST分型分析..."
echo "[INFO] BLAST结果目录：${BLAST_RESULTS_DIR}"
echo "[INFO] MLST配置目录：${PROFILES_DIR}"
echo "[INFO] 输出目录：${OUTPUT_DIR}"
echo "[INFO] 质量控制：相似度≥${MIN_IDENTITY}%, 覆盖度≥${MIN_COVERAGE}%"
echo

# 创建输出目录
mkdir -p "${OUTPUT_DIR}"

# 运行Python脚本
python3 "${PYTHON_SCRIPT}" "${ARGS[@]}"

# === 结果展示 ===
echo
echo "=" * 60
echo "🎉 MLST分型分析完成！"
echo "=" * 60

# 显示输出文件
if [[ -f "${OUTPUT_DIR}/MLST_summary.csv" ]]; then
    echo
    echo "📊 分型结果汇总："
    echo "----------------------------------------"
    echo "样本名称,Oxford ST,Pasteur ST,状态"
    tail -n +2 "${OUTPUT_DIR}/MLST_summary.csv" | while IFS=',' read -r sample oxford_st oxford_cc oxford_species pasteur_st pasteur_cc pasteur_species status; do
        echo "${sample},${oxford_st},${pasteur_st},${status}"
    done
    echo
fi

echo "📁 输出文件："
echo "   详细报告：${OUTPUT_DIR}/MLST_detailed_report.txt"
echo "   汇总表格：${OUTPUT_DIR}/MLST_summary.csv"
echo
echo "💡 提示："
echo "   - 查看详细报告：less '${OUTPUT_DIR}/MLST_detailed_report.txt'"
echo "   - 查看汇总表格：column -t -s, '${OUTPUT_DIR}/MLST_summary.csv'"
echo "   - 在Excel中打开：可直接打开CSV文件"