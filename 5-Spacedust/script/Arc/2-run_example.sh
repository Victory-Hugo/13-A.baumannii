#!/bin/bash

# Spacedust 示例运行脚本
# 使用Example目录中的示例数据进行测试

set -e

# 脚本所在目录
SCRIPT_DIR="/mnt/f/OneDrive/文档（科研）/脚本/Download/13-A.baumannii/5-Spacedust/script/"
BASE_DIR="/mnt/f/OneDrive/文档（科研）/脚本/Download/13-A.baumannii/5-Spacedust"

# 加载配置
source "${SCRIPT_DIR}/1-5-config.sh"

# 设置路径
EXAMPLE_DIR="${BASE_DIR}/Example"
OUTPUT_DIR="${BASE_DIR}/example_output"

# 颜色输出
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}=== Spacedust 示例分析 ===${NC}"
echo -e "${BLUE}使用Example目录中的示例数据${NC}"
echo

# 检查示例数据
if [[ ! -d "$EXAMPLE_DIR" ]]; then
    echo -e "${YELLOW}错误: 示例数据目录不存在: $EXAMPLE_DIR${NC}"
    exit 1
fi

# 统计示例文件
fna_files=($(find "$EXAMPLE_DIR" -name "*.fna" -type f 2>/dev/null))
faa_files=($(find "$EXAMPLE_DIR" -name "*.faa" -type f 2>/dev/null))

echo -e "${BLUE}找到的示例文件:${NC}"
echo "  FNA文件数: ${#fna_files[@]}"
echo "  FAA文件数: ${#faa_files[@]}"

if [[ ${#fna_files[@]} -eq 0 && ${#faa_files[@]} -eq 0 ]]; then
    echo -e "${YELLOW}错误: 在示例目录中未找到.fna或.faa文件${NC}"
    exit 1
fi

echo

# 创建输出目录
mkdir -p "$OUTPUT_DIR"

# 选择运行模式
if [[ ${#fna_files[@]} -gt 0 ]]; then
    echo -e "${GREEN}使用FNA文件，将运行Prodigal进行基因预测${NC}"
    INPUT_FILES_TYPE="fna"
    RUN_PRODIGAL_FLAG="true"
else
    echo -e "${GREEN}使用FAA文件，跳过Prodigal基因预测${NC}"
    INPUT_FILES_TYPE="faa"
    RUN_PRODIGAL_FLAG="false"
fi

# 根据文件数量选择模式
if [[ ${#fna_files[@]} -gt 1 || ${#faa_files[@]} -gt 1 ]]; then
    echo -e "${GREEN}检测到多个文件，可以使用all-against-all模式${NC}"
    echo "请选择运行模式:"
    echo "1) query-target (与KEGG数据库比较)"
    echo "2) all-against-all (文件间两两比较)"
    echo -n "请输入选择 [1]: "
    read -r choice
    
    if [[ "$choice" == "2" ]]; then
        ANALYSIS_MODE="all-against-all"
        TARGET_DATABASE="self-uploaded"  # all-against-all模式下此参数会被忽略
        echo -e "${GREEN}选择: all-against-all 模式${NC}"
    else
        ANALYSIS_MODE="query-target"
        TARGET_DATABASE="KEGG_70"
        echo -e "${GREEN}选择: query-target 模式（与KEGG数据库比较）${NC}"
    fi
else
    ANALYSIS_MODE="query-target"
    TARGET_DATABASE="KEGG_70"
    echo -e "${GREEN}单个文件，使用query-target模式与KEGG数据库比较${NC}"
fi

echo

# 运行分析
echo -e "${BLUE}开始运行Spacedust分析...${NC}"
echo "参数配置:"
echo "  输入目录: $EXAMPLE_DIR"
echo "  输出目录: $OUTPUT_DIR"
echo "  分析模式: $ANALYSIS_MODE"
echo "  目标数据库: $TARGET_DATABASE"
echo "  运行Prodigal: $RUN_PRODIGAL_FLAG"
echo "  任务名称: example_analysis"
echo

# 构建运行命令
cmd=(
    "${SCRIPT_DIR}/run_spacedust.sh"
    --input "$EXAMPLE_DIR"
    --jobname "example_analysis"
    --mode "$ANALYSIS_MODE"
    --database "$TARGET_DATABASE"
    --prodigal "$RUN_PRODIGAL_FLAG"
    --output "$OUTPUT_DIR"
    --workdir "$OUTPUT_DIR"
)

echo -e "${BLUE}执行命令:${NC}"
echo "${cmd[*]}"
echo

# 执行分析
if "${cmd[@]}"; then
    echo
    echo -e "${GREEN}=== 分析完成！ ===${NC}"
    echo -e "${GREEN}结果文件保存在: $OUTPUT_DIR${NC}"
    echo
    echo "主要输出文件:"
    
    # 列出结果文件
    if [[ -f "$OUTPUT_DIR/example_analysis" ]]; then
        echo -e "  ${GREEN}✓${NC} example_analysis - 主要结果文件"
    fi
    
    if [[ -f "$OUTPUT_DIR/example_analysis_plot" ]]; then
        echo -e "  ${GREEN}✓${NC} example_analysis_plot - 可视化数据文件"
    fi
    
    if [[ -f "$OUTPUT_DIR/example_analysis_statistics.txt" ]]; then
        echo -e "  ${GREEN}✓${NC} example_analysis_statistics.txt - 统计信息"
        echo
        echo -e "${BLUE}统计信息预览:${NC}"
        head -20 "$OUTPUT_DIR/example_analysis_statistics.txt" | sed 's/^/  /'
    fi
    
    if [[ -f "$OUTPUT_DIR/database/example_analysis_input_pref" ]]; then
        echo -e "  ${GREEN}✓${NC} database/example_analysis_input_pref - 前缀数据"
    fi
    
    echo
    echo -e "${BLUE}如需查看完整结果，请检查输出目录: $OUTPUT_DIR${NC}"
    
else
    echo
    echo -e "${YELLOW}分析过程中出现错误，请检查日志信息${NC}"
    exit 1
fi