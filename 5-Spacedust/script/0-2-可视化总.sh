#!/bin/bash
#
# Spacedust完整可视化流程脚本
# 整合Python和R脚本，忠实于原始Jupyter Notebook源代码
#
# 使用方法:
#   ./spacedust_visualize.sh [选项]
#
#todo conda activate pyg
# 默认参数
DATA_DIR="/mnt/f/OneDrive/文档（科研）/脚本/Download/13-A.baumannii/5-Spacedust/output/"
JOBNAME="Test" #TODO 作业名称
OUTPUT_DIR="${DATA_DIR}/image/faithful"
GENOME=""
PROTEIN_ID="1"
ZOOM=false #TODO 是否缩放，默认不缩放
LOWER_BOUND=1 #TODO 缩放下界，默认1
UPPER_BOUND=100 #TODO 缩放上界，默认100
WINDOW_SIZE=100 #TODO 滑动窗口大小，默认100

# 脚本目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 帮助信息
show_help() {
    cat << EOF
Spacedust完整可视化流程
======================

使用方法: $0 [选项]

选项:
    -d, --data-dir DIR      数据目录 (默认: $DATA_DIR)
    -j, --jobname NAME      作业名称 (默认: $JOBNAME)
    -o, --output-dir DIR    输出目录 (默认: $OUTPUT_DIR)
    -g, --genome NAME       指定查询基因组名称
    -p, --protein-id ID     查询蛋白质ID (默认: $PROTEIN_ID)
    -z, --zoom              启用缩放
    -l, --lower-bound NUM   缩放下界 (默认: $LOWER_BOUND)
    -u, --upper-bound NUM   缩放上界 (默认: $UPPER_BOUND)
    -w, --window-size NUM   滑动窗口大小 (默认: $WINDOW_SIZE)
    -h, --help              显示此帮助信息

示例:
    $0                                          # 使用默认参数
    $0 -d /path/to/data -j MyJob                # 指定数据目录和作业名
    $0 -g ERR1417337.faa -p 5                  # 指定基因组和蛋白质ID
    $0 -z -l 10 -u 50                          # 启用缩放并指定范围

EOF
}

# 解析命令行参数
while [[ $# -gt 0 ]]; do
    case $1 in
        -d|--data-dir)
            DATA_DIR="$2"
            shift 2
            ;;
        -j|--jobname)
            JOBNAME="$2"
            shift 2
            ;;
        -o|--output-dir)
            OUTPUT_DIR="$2"
            shift 2
            ;;
        -g|--genome)
            GENOME="$2"
            shift 2
            ;;
        -p|--protein-id)
            PROTEIN_ID="$2"
            shift 2
            ;;
        -z|--zoom)
            ZOOM=true
            shift
            ;;
        -l|--lower-bound)
            LOWER_BOUND="$2"
            shift 2
            ;;
        -u|--upper-bound)
            UPPER_BOUND="$2"
            shift 2
            ;;
        -w|--window-size)
            WINDOW_SIZE="$2"
            shift 2
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            echo "未知选项: $1"
            echo "使用 -h 或 --help 查看帮助信息"
            exit 1
            ;;
    esac
done

# 验证必要的参数
if [[ ! -d "$DATA_DIR" ]]; then
    echo "错误: 数据目录不存在: $DATA_DIR"
    exit 1
fi

# 创建输出目录
mkdir -p "$OUTPUT_DIR"

# 显示配置信息
echo "Spacedust完整可视化流程"
echo "======================"
echo "数据目录: $DATA_DIR"
echo "作业名称: $JOBNAME"
echo "输出目录: $OUTPUT_DIR"
if [[ -n "$GENOME" ]]; then
    echo "查询基因组: $GENOME"
else
    echo "查询基因组: 自动选择"
fi
echo "蛋白质ID: $PROTEIN_ID"
if [[ "$ZOOM" == "true" ]]; then
    echo "缩放: 是 ($LOWER_BOUND-$UPPER_BOUND)"
else
    echo "缩放: 否"
fi
echo "窗口大小: $WINDOW_SIZE"
echo ""

# 构建Python命令
PYTHON_CMD="python $SCRIPT_DIR/1-可视化热图条形图.py"
PYTHON_CMD="$PYTHON_CMD --data-dir '$DATA_DIR'"
PYTHON_CMD="$PYTHON_CMD --jobname '$JOBNAME'"
PYTHON_CMD="$PYTHON_CMD --output-dir '$OUTPUT_DIR'"
PYTHON_CMD="$PYTHON_CMD --query-protein-id '$PROTEIN_ID'"
PYTHON_CMD="$PYTHON_CMD --window-size $WINDOW_SIZE"

if [[ -n "$GENOME" ]]; then
    PYTHON_CMD="$PYTHON_CMD --genome '$GENOME'"
fi

if [[ "$ZOOM" == "true" ]]; then
    PYTHON_CMD="$PYTHON_CMD --zoom --lower-bound $LOWER_BOUND --upper-bound $UPPER_BOUND"
fi

# 执行Python可视化
echo "步骤 1/2: 执行Python可视化..."
echo "命令: $PYTHON_CMD"
echo ""

if eval "$PYTHON_CMD"; then
    echo ""
    echo "✅ Python可视化完成!"
else
    echo "❌ 错误: Python可视化失败 (退出码: $?)"
    exit 1
fi

# 检查是否生成了数据文件
DATA_FILE="$OUTPUT_DIR/gggene_data_for_r.csv"
if [[ ! -f "$DATA_FILE" ]]; then
    echo "⚠️  警告: 未找到R数据文件: $DATA_FILE"
    echo "跳过R可视化步骤"
    DATA_FILE=""
fi

# 执行R可视化
if [[ -n "$DATA_FILE" ]]; then
    echo "步骤 2/2: 执行R基因组上下文可视化..."
    echo "数据文件: $DATA_FILE"
    echo "命令: Rscript $SCRIPT_DIR/2-可视化上下文.R '$DATA_FILE' '$OUTPUT_DIR' '$PROTEIN_ID'"
    echo ""
    
    if Rscript "$SCRIPT_DIR/2-可视化上下文.R" "$DATA_FILE" "$OUTPUT_DIR" "$PROTEIN_ID"; then
        echo ""
        echo "✅ R可视化完成!"
    else
        echo "⚠️  警告: R可视化失败 (退出码: $?)"
        echo "Python可视化已完成，可以查看生成的图像"
    fi
else
    echo "步骤 2/2: 跳过R可视化（无数据文件）"
fi

# 生成最终报告
echo ""
echo "步骤 3/3: 生成最终报告..."

REPORT_FILE="$OUTPUT_DIR/visualization_report.txt"

cat > "$REPORT_FILE" << EOF
Spacedust可视化完成报告
========================

生成时间: $(date)
数据目录: $DATA_DIR
作业名称: $JOBNAME
输出目录: $OUTPUT_DIR
查询基因组: $(if [[ -n "$GENOME" ]]; then echo "$GENOME"; else echo "自动选择"; fi)
蛋白质ID: $PROTEIN_ID
缩放设置: $(if [[ "$ZOOM" == "true" ]]; then echo "启用 ($LOWER_BOUND-$UPPER_BOUND)"; else echo "禁用"; fi)
窗口大小: $WINDOW_SIZE

生成的文件:
===========

Python可视化输出:
$(find "$OUTPUT_DIR" -name "faithful_*.png" -o -name "faithful_*.pdf" | sort | sed 's|.*/||g' | sed 's/^/  /')

R可视化输出:
$(find "$OUTPUT_DIR" -name "spacedust_*.png" | sort | sed 's|.*/||g' | sed 's/^/  /')

数据文件:
$(find "$OUTPUT_DIR" -name "*.csv" | sort | sed 's|.*/||g' | sed 's/^/  /')

报告文件:
$(find "$OUTPUT_DIR" -name "*.txt" | sort | sed 's|.*/||g' | sed 's/^/  /')

总计: $(find "$OUTPUT_DIR" -type f | wc -l) 个文件
EOF

echo "📄 最终报告已保存: $REPORT_FILE"

# 统计生成的文件
FILE_COUNT=$(find "$OUTPUT_DIR" -type f | wc -l)

echo ""
echo "🎉 ================================"
echo "    可视化流程完成!"
echo "   ================================"
echo "📁 输出目录: $OUTPUT_DIR"
echo "📊 总共生成: $FILE_COUNT 个文件"
echo ""
echo "主要输出文件:"
find "$OUTPUT_DIR" -name "*.png" -o -name "*.pdf" | sort | head -5 | while read file; do
    echo "  📈 $(basename "$file")"
done

if [[ $FILE_COUNT -gt 5 ]]; then
    echo "  📝 ... 还有 $((FILE_COUNT - 5)) 个文件"
fi

echo ""
echo "📖 查看报告: cat '$REPORT_FILE'"
echo "🖼️  查看图像: ls '$OUTPUT_DIR'/*.png"
echo "📁 打开目录: cd '$OUTPUT_DIR'"