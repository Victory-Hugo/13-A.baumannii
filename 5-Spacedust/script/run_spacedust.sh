#!/bin/bash

# Spacedust 分析主脚本
# 功能：对微生物基因组进行保守基因簇分析
# 作者：整理自Jupyter notebook

set -e  # 遇到错误时退出
set -u  # 使用未定义变量时退出

# 脚本所在目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(dirname "$SCRIPT_DIR")"

# 默认参数设置
JOBNAME="test"
INPUT_MODE="query-target"  # query-target 或 all-against-all
TARGET_DB="KEGG_70"        # self-uploaded 或 KEGG_70
SEARCH_MODE="MMseqs2"      # MMseqs2 或 Foldseek
RUN_PRODIGAL=true          # true 或 false
MAX_GENE_GAP=3
NUM_ITERATIONS=1

# 路径设置
INPUT_DIR=""
TARGET_DIR=""
OUTPUT_DIR="$(pwd)/spacedust_output"
WORK_DIR="$(pwd)"

# 软件路径
SPACEDUST_BIN="${BASE_DIR}/download/spacedust/bin/spacedust"
PRODIGAL_BIN="${BASE_DIR}/download/prodigal/bin/prodigal.linux"
DATABASE_DIR="${BASE_DIR}/database"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 打印带颜色的消息
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
    exit 1
}

# 显示使用帮助
show_help() {
    cat << EOF
用法: $0 [选项]

Spacedust 微生物基因组保守基因簇分析工具

必需参数:
  -i, --input DIR          输入基因组文件目录

可选参数:
  -j, --jobname NAME       任务名称 (默认: test)
  -m, --mode MODE          输入模式: query-target 或 all-against-all (默认: query-target)
  -d, --database DB        目标数据库: KEGG_70 或 self-uploaded (默认: KEGG_70)
  -t, --target DIR         目标基因组文件目录 (当数据库为self-uploaded时使用)
  -s, --search MODE        搜索模式: MMseqs2 或 Foldseek (默认: MMseqs2)
  -p, --prodigal           运行Prodigal进行基因预测 (默认: true)
  -g, --max-gap NUM        最大基因间隔 (默认: 3)
  -o, --output DIR         输出目录 (默认: ./spacedust_output)
  -w, --workdir DIR        工作目录 (默认: 当前目录)
  -h, --help               显示此帮助信息

示例:
  # 基本用法：使用KEGG数据库分析基因组
  $0 -i /path/to/genomes -j my_analysis

  # all-against-all模式分析
  $0 -i /path/to/genomes -j all_vs_all -m all-against-all

  # 使用自定义目标数据库
  $0 -i /path/to/query_genomes -t /path/to/target_genomes -d self-uploaded -j custom_analysis

  # 不运行Prodigal（输入已经是.faa文件）
  $0 -i /path/to/genomes -j no_prodigal --prodigal false
EOF
}

# 解析命令行参数
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -i|--input)
                INPUT_DIR="$2"
                shift 2
                ;;
            -j|--jobname)
                JOBNAME="$2"
                shift 2
                ;;
            -m|--mode)
                INPUT_MODE="$2"
                shift 2
                ;;
            -d|--database)
                TARGET_DB="$2"
                shift 2
                ;;
            -t|--target)
                TARGET_DIR="$2"
                shift 2
                ;;
            -s|--search)
                SEARCH_MODE="$2"
                shift 2
                ;;
            -p|--prodigal)
                RUN_PRODIGAL="$2"
                shift 2
                ;;
            -g|--max-gap)
                MAX_GENE_GAP="$2"
                shift 2
                ;;
            -o|--output)
                OUTPUT_DIR="$2"
                shift 2
                ;;
            -w|--workdir)
                WORK_DIR="$2"
                shift 2
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            *)
                print_error "未知参数: $1"
                ;;
        esac
    done
}

# 验证参数
validate_parameters() {
    # 检查必需参数
    if [[ -z "$INPUT_DIR" ]]; then
        print_error "必须指定输入目录 (-i|--input)"
    fi

    # 检查输入目录是否存在
    if [[ ! -d "$INPUT_DIR" ]]; then
        print_error "输入目录不存在: $INPUT_DIR"
    fi

    # 检查输入模式
    if [[ "$INPUT_MODE" != "query-target" && "$INPUT_MODE" != "all-against-all" ]]; then
        print_error "输入模式必须是 'query-target' 或 'all-against-all'"
    fi

    # 检查目标数据库
    if [[ "$TARGET_DB" != "KEGG_70" && "$TARGET_DB" != "self-uploaded" ]]; then
        print_error "目标数据库必须是 'KEGG_70' 或 'self-uploaded'"
    fi

    # 检查搜索模式
    if [[ "$SEARCH_MODE" != "MMseqs2" && "$SEARCH_MODE" != "Foldseek" ]]; then
        print_error "搜索模式必须是 'MMseqs2' 或 'Foldseek'"
    fi

    # 如果使用自上传数据库，检查目标目录
    if [[ "$INPUT_MODE" == "query-target" && "$TARGET_DB" == "self-uploaded" ]]; then
        if [[ -z "$TARGET_DIR" ]]; then
            print_error "使用自上传数据库时必须指定目标目录 (-t|--target)"
        fi
        if [[ ! -d "$TARGET_DIR" ]]; then
            print_error "目标目录不存在: $TARGET_DIR"
        fi
    fi

    # 检查软件可执行文件
    if [[ ! -x "$SPACEDUST_BIN" ]]; then
        print_error "Spacedust可执行文件不存在或无执行权限: $SPACEDUST_BIN"
    fi

    if [[ "$RUN_PRODIGAL" == "true" && ! -x "$PRODIGAL_BIN" ]]; then
        print_error "Prodigal可执行文件不存在或无执行权限: $PRODIGAL_BIN"
    fi

    # 检查数据库
    if [[ "$TARGET_DB" == "KEGG_70" && ! -f "${DATABASE_DIR}/KEGG_70/keggclusterdb" ]]; then
        print_error "KEGG数据库不存在: ${DATABASE_DIR}/KEGG_70/keggclusterdb"
    fi
}

# 设置工作环境
setup_environment() {
    print_info "设置工作环境..."
    
    # 创建输出目录
    mkdir -p "$OUTPUT_DIR"
    
    # 进入工作目录
    cd "$WORK_DIR"
    
    # 创建必要的子目录
    mkdir -p database tmp
    
    # 创建输出目录的符号链接（如果需要）
    if [[ "$OUTPUT_DIR" != "$WORK_DIR" ]]; then
        ln -sf "$OUTPUT_DIR" "./output"
    fi
}

# 检查输入文件
check_input_files() {
    print_info "检查输入文件..."
    
    # 检查输入文件数量
    if [[ "$RUN_PRODIGAL" == "true" ]]; then
        local input_files=($(find "$INPUT_DIR" -name "*.fna" -type f))
        local file_type="FNA"
    else
        local input_files=($(find "$INPUT_DIR" -name "*.faa" -type f))
        local file_type="FAA"
    fi
    
    local num_input=${#input_files[@]}
    print_info "找到 $num_input 个 $file_type 输入文件"
    
    if [[ $num_input -eq 0 ]]; then
        print_error "在输入目录中未找到 $file_type 文件: $INPUT_DIR"
    fi
    
    # 检查all-against-all模式的文件数量要求
    if [[ "$INPUT_MODE" == "all-against-all" && $num_input -le 1 ]]; then
        print_error "all-against-all模式需要多于1个输入文件"
    fi
    
    # 检查目标文件（如果需要）
    if [[ "$INPUT_MODE" == "query-target" && "$TARGET_DB" == "self-uploaded" ]]; then
        if [[ "$RUN_PRODIGAL" == "true" ]]; then
            local target_files=($(find "$TARGET_DIR" -name "*.fna" -type f))
        else
            local target_files=($(find "$TARGET_DIR" -name "*.faa" -type f))
        fi
        
        local num_target=${#target_files[@]}
        print_info "找到 $num_target 个 $file_type 目标文件"
        
        if [[ $num_target -eq 0 ]]; then
            print_error "在目标目录中未找到 $file_type 文件: $TARGET_DIR"
        fi
    fi
}

# 运行Prodigal基因预测
run_prodigal() {
    if [[ "$RUN_PRODIGAL" != "true" ]]; then
        print_info "跳过Prodigal基因预测"
        return 0
    fi
    
    if [[ -f "PRODIGAL_FAA_READY" ]]; then
        print_info "Prodigal已运行过，跳过"
        return 0
    fi
    
    print_info "开始运行Prodigal进行基因预测..."
    
    # 处理输入文件
    local fna_files=($(find "$INPUT_DIR" -name "*.fna" -type f))
    for fna_file in "${fna_files[@]}"; do
        local base_name=$(basename "$fna_file" .fna)
        local faa_file="${INPUT_DIR}/${base_name}.faa"
        
        if [[ ! -f "$faa_file" ]]; then
            print_info "处理: $base_name"
            "$PRODIGAL_BIN" -i "$fna_file" -a "$faa_file" -q
        fi
    done
    
    # 处理目标文件（如果需要）
    if [[ "$INPUT_MODE" == "query-target" && "$TARGET_DB" == "self-uploaded" ]]; then
        local target_fna_files=($(find "$TARGET_DIR" -name "*.fna" -type f))
        for fna_file in "${target_fna_files[@]}"; do
            local base_name=$(basename "$fna_file" .fna)
            local faa_file="${TARGET_DIR}/${base_name}.faa"
            
            if [[ ! -f "$faa_file" ]]; then
                print_info "处理目标文件: $base_name"
                "$PRODIGAL_BIN" -i "$fna_file" -a "$faa_file" -q
            fi
        done
    fi
    
    touch "PRODIGAL_FAA_READY"
    print_success "Prodigal基因预测完成"
}

# 运行Spacedust分析
run_spacedust() {
    print_info "开始运行Spacedust分析..."
    
    # 设置搜索类型
    local search_type=0
    if [[ "$SEARCH_MODE" == "Foldseek" ]]; then
        search_type=1
    fi
    
    local input_type=0
    if [[ "$INPUT_MODE" == "all-against-all" ]]; then
        input_type=1
    fi
    
    local target_type=0
    if [[ "$TARGET_DB" != "self-uploaded" ]]; then
        target_type=1
    fi
    
    # 获取FAA文件列表
    local faa_files=($(find "$INPUT_DIR" -name "*.faa" -type f))
    
    if [[ $input_type -eq 1 ]]; then
        # all-against-all 模式
        print_info "运行all-against-all模式..."
        
        # 创建数据库
        print_info "创建输入数据库..."
        "$SPACEDUST_BIN" createsetdb "${faa_files[@]}" "${WORK_DIR}/database/${JOBNAME}_input" tmp --write-lookup 0 -v 1
        
        # 运行聚类搜索
        print_info "运行聚类搜索..."
        "$SPACEDUST_BIN" clustersearch "${WORK_DIR}/database/${JOBNAME}_input" "${WORK_DIR}/database/${JOBNAME}_input" \
            "$JOBNAME" tmp --filter-self-match --search-mode "$search_type" \
            --max-gene-gap "$MAX_GENE_GAP" -v 1
    else
        # query-target 模式
        print_info "运行query-target模式..."
        
        # 创建查询数据库
        print_info "创建查询数据库..."
        "$SPACEDUST_BIN" createsetdb "${faa_files[@]}" "${WORK_DIR}/database/${JOBNAME}_input" tmp --write-lookup 0 -v 1
        
        if [[ $target_type -eq 0 ]]; then
            # 自上传目标数据库
            print_info "创建目标数据库..."
            local target_faa_files=($(find "$TARGET_DIR" -name "*.faa" -type f))
            "$SPACEDUST_BIN" createsetdb "${target_faa_files[@]}" "${WORK_DIR}/database/${JOBNAME}_db" tmp --write-lookup 0 -v 1
            
            print_info "运行聚类搜索（自定义目标）..."
            "$SPACEDUST_BIN" clustersearch "${WORK_DIR}/database/${JOBNAME}_input" "${WORK_DIR}/database/${JOBNAME}_db" \
                "$JOBNAME" tmp --search-mode "$search_type" --max-gene-gap "$MAX_GENE_GAP" -v 1
        else
            # 使用预建数据库
            print_info "运行聚类搜索（KEGG数据库）..."
            "$SPACEDUST_BIN" clustersearch "${WORK_DIR}/database/${JOBNAME}_input" "${DATABASE_DIR}/KEGG_70/keggclusterdb" \
                "$JOBNAME" tmp --search-mode "$search_type" --max-gene-gap "$MAX_GENE_GAP" -v 1
        fi
    fi
    
    print_success "Spacedust聚类搜索完成"
}

# 生成前缀ID
generate_prefix_id() {
    print_info "生成前缀ID..."
    
    "$SPACEDUST_BIN" prefixid tmp/latest/clusters "${JOBNAME}_pref" --tsv -v 1
    "$SPACEDUST_BIN" prefixid "${WORK_DIR}/database/${JOBNAME}_input" "${WORK_DIR}/database/${JOBNAME}_input_pref" --tsv -v 1
    
    print_success "前缀ID生成完成"
}

# 调用Python脚本进行后处理
run_post_processing() {
    print_info "开始后处理结果..."
    
    # 创建Python脚本的参数
    local python_args=(
        "--jobname" "$JOBNAME"
        "--input-mode" "$INPUT_MODE"
        "--target-db" "$TARGET_DB"
        "--workdir" "$WORK_DIR"
    )
    
    # 调用Python后处理脚本
    python3 "${SCRIPT_DIR}/spacedust_postprocess.py" "${python_args[@]}"
    
    if [[ $? -eq 0 ]]; then
        print_success "后处理完成"
    else
        print_error "后处理失败"
    fi
}

# 清理临时文件
cleanup() {
    print_info "清理临时文件..."
    
    # 移动结果文件到输出目录
    if [[ -f "${JOBNAME}" ]]; then
        mv "${JOBNAME}" "$OUTPUT_DIR/"
    fi
    
    if [[ -f "${JOBNAME}_plot" ]]; then
        mv "${JOBNAME}_plot" "$OUTPUT_DIR/"
    fi
    
    if [[ -f "${WORK_DIR}/database/${JOBNAME}_input_pref" ]]; then
        mv "${WORK_DIR}/database/${JOBNAME}_input_pref" "$OUTPUT_DIR/"
    fi
    
    # 可选：删除临时文件
    # rm -rf tmp
    
    print_info "结果文件已保存到: $OUTPUT_DIR"
}

# 主函数
main() {
    print_info "开始Spacedust分析流程..."
    print_info "脚本版本: 基于Jupyter notebook重构"
    
    # 解析命令行参数
    parse_arguments "$@"
    
    # 验证参数
    validate_parameters
    
    # 显示配置信息
    print_info "=== 分析配置 ==="
    print_info "任务名称: $JOBNAME"
    print_info "输入模式: $INPUT_MODE"
    print_info "目标数据库: $TARGET_DB"
    print_info "搜索模式: $SEARCH_MODE"
    print_info "运行Prodigal: $RUN_PRODIGAL"
    print_info "最大基因间隔: $MAX_GENE_GAP"
    print_info "输入目录: $INPUT_DIR"
    if [[ -n "$TARGET_DIR" ]]; then
        print_info "目标目录: $TARGET_DIR"
    fi
    print_info "输出目录: $OUTPUT_DIR"
    print_info "工作目录: $WORK_DIR"
    print_info "================="
    
    # 设置环境
    setup_environment
    
    # 检查输入文件
    check_input_files
    
    # 运行分析流程
    run_prodigal
    run_spacedust
    generate_prefix_id
    run_post_processing
    cleanup
    
    print_success "Spacedust分析完成！"
    print_info "查看结果文件: $OUTPUT_DIR"
}

# 如果脚本被直接执行（不是被source），则运行主函数
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi