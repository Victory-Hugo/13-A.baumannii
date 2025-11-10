#!/bin/bash
# 快速开始：AMRFinder 结果数据转换和分析
# 使用这个脚本来执行完整的数据处理流程

set -e

# ============ 配置区 ============
INPUT_CSV="/mnt/d/1-ABaumannii/1-注释汇总/input/抗生素耐药_合并.csv"
OUTPUT_DIR="/mnt/d/1-ABaumannii/1-注释汇总/output"
SCRIPT_DIR="/mnt/f/OneDrive/文档（科研）/脚本/Download/13-A.baumannii/4-注释/8-结果整理/script"

# ============ 色彩定义 ============
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ============ 函数定义 ============
log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

log_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

log_warn() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

log_error() {
    echo -e "${RED}✗ $1${NC}"
}

# ============ 主流程 ============
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}🧬 AMRFinder 结果数据转换和分析${NC}"
echo -e "${BLUE}========================================${NC}\n"

# 检查输入文件
if [[ ! -f "$INPUT_CSV" ]]; then
    log_error "输入文件不存在: $INPUT_CSV"
    exit 1
fi
log_success "找到输入文件: $INPUT_CSV"

# 创建输出目录
mkdir -p "$OUTPUT_DIR"
log_success "输出目录: $OUTPUT_DIR"

# Step 1: 数据格式转换
echo -e "\n${YELLOW}━━━ Step 1: 数据格式转换 ━━━${NC}"
log_info "将AMRFinder结果转换为7种分析格式..."
python3 "$SCRIPT_DIR/2-AMR_format_conversion.py" "$INPUT_CSV" "$OUTPUT_DIR"

if [[ $? -eq 0 ]]; then
    log_success "格式转换完成"
else
    log_error "格式转换失败"
    exit 1
fi

# Step 2: 数据分析
echo -e "\n${YELLOW}━━━ Step 2: 数据分析 ━━━${NC}"
log_info "执行5项深度分析..."
python3 "$SCRIPT_DIR/3-format_analysis_examples.py" "$OUTPUT_DIR"

if [[ $? -eq 0 ]]; then
    log_success "数据分析完成"
else
    log_error "数据分析失败"
    exit 1
fi



log_success "生成统计摘要"
cat "$OUTPUT_DIR/SUMMARY.txt"

# 最终总结
echo -e "\n${BLUE}========================================${NC}"
echo -e "${GREEN}✅ 所有数据处理完成！${NC}"
echo -e "${BLUE}========================================${NC}\n"

echo -e "📊 ${YELLOW}生成的文件位置：${NC}"
echo "   📁 $OUTPUT_DIR"
echo ""
echo -e "📄 ${YELLOW}主要输出文件：${NC}"
ls -lh "$OUTPUT_DIR"/*.csv 2>/dev/null | awk '{print "   " $9}'
echo ""
echo -e "🔍 ${YELLOW}分析结果：${NC}"
if [[ -d "$OUTPUT_DIR/analyses" ]]; then
    ls -lh "$OUTPUT_DIR/analyses"/*.csv 2>/dev/null | awk '{print "   " $9}'
fi
echo ""
echo -e "📖 ${YELLOW}下一步建议：${NC}"
echo "   1. 查看 $OUTPUT_DIR/SUMMARY.txt 了解数据格式"
echo "   2. 用Excel打开 phenotype_summary.csv 进行快速浏览"
echo "   3. 用R或Python运行 visualization_examples.R/py 制作图表"
echo "   4. 在Cytoscape中导入 network_data.json 进行网络分析"
echo ""
