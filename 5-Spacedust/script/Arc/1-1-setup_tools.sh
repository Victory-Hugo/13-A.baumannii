#!/bin/bash

# Spacedust 工具设置脚本
# 功能：检查和设置软件路径，确保所有依赖软件可用

set -e

# 脚本所在目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(dirname "$SCRIPT_DIR")"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 软件路径
DOWNLOAD_DIR="${BASE_DIR}/download"
DATABASE_DIR="${BASE_DIR}/database"

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
}

# 检查目录结构
check_directory_structure() {
    print_info "检查目录结构..."
    
    local dirs=(
        "$DOWNLOAD_DIR"
        "$DATABASE_DIR"
        "${BASE_DIR}/Example"
        "${BASE_DIR}/script"
    )
    
    for dir in "${dirs[@]}"; do
        if [[ -d "$dir" ]]; then
            print_success "目录存在: $dir"
        else
            print_warning "目录不存在: $dir"
        fi
    done
}

# 检查Spacedust软件
check_spacedust() {
    print_info "检查Spacedust软件..."
    
    local spacedust_paths=(
        "${DOWNLOAD_DIR}/spacedust/bin/spacedust"
        "${DOWNLOAD_DIR}/spacedust"
    )
    
    for path in "${spacedust_paths[@]}"; do
        if [[ -x "$path" ]]; then
            print_success "Spacedust可执行文件: $path"
            # 测试运行
            if "$path" -h &>/dev/null; then
                print_success "Spacedust软件可正常运行"
            else
                print_warning "Spacedust软件运行测试失败"
            fi
            return 0
        fi
    done
    
    print_error "未找到Spacedust可执行文件"
    return 1
}

# 检查Prodigal软件
check_prodigal() {
    print_info "检查Prodigal软件..."
    
    local prodigal_paths=(
        "${DOWNLOAD_DIR}/prodigal/bin/prodigal.linux"
        "${DOWNLOAD_DIR}/prodigal/prodigal"
        "$(which prodigal 2>/dev/null || true)"
    )
    
    for path in "${prodigal_paths[@]}"; do
        if [[ -n "$path" && -x "$path" ]]; then
            print_success "Prodigal可执行文件: $path"
            # 测试运行
            if "$path" -h &>/dev/null; then
                print_success "Prodigal软件可正常运行"
            else
                print_warning "Prodigal软件运行测试失败"
            fi
            return 0
        fi
    done
    
    print_warning "未找到Prodigal可执行文件（如不需要基因预测可忽略）"
    return 1
}

# 检查Foldseek软件（可选）
check_foldseek() {
    print_info "检查Foldseek软件（可选）..."
    
    local foldseek_paths=(
        "${DOWNLOAD_DIR}/foldseek/bin/foldseek"
        "${DOWNLOAD_DIR}/foldseek"
        "$(which foldseek 2>/dev/null || true)"
    )
    
    for path in "${foldseek_paths[@]}"; do
        if [[ -n "$path" && -x "$path" ]]; then
            print_success "Foldseek可执行文件: $path"
            # 测试运行
            if "$path" -h &>/dev/null; then
                print_success "Foldseek软件可正常运行"
            else
                print_warning "Foldseek软件运行测试失败"
            fi
            return 0
        fi
    done
    
    print_warning "未找到Foldseek可执行文件（仅在使用结构搜索时需要）"
    return 1
}

# 检查数据库
check_databases() {
    print_info "检查数据库..."
    
    # 检查KEGG数据库
    local kegg_db_path="${DATABASE_DIR}/KEGG_70/keggclusterdb"
    if [[ -f "$kegg_db_path" ]]; then
        print_success "KEGG数据库目录存在: $kegg_db_path"
        
        # 检查重要文件
        local important_files=(
            "${kegg_db_path}.dbtype"
            "${kegg_db_path}.lookup"
            "${kegg_db_path}.source"
        )
        
        local file_count=0
        for file in "${important_files[@]}"; do
            if [[ -f "$file" ]]; then
                ((file_count++))
            fi
        done
        
        if [[ $file_count -gt 0 ]]; then
            print_success "KEGG数据库文件检查通过 ($file_count/3 个关键文件存在)"
        else
            print_warning "KEGG数据库文件不完整"
        fi
    else
        print_warning "KEGG数据库目录不存在: $kegg_db_path"
        print_warning "如需使用KEGG数据库，请确保已正确解压数据库文件"
    fi
}

# 检查示例数据
check_example_data() {
    print_info "检查示例数据..."
    
    local example_dir="${BASE_DIR}/Example"
    if [[ -d "$example_dir" ]]; then
        local fna_files=($(find "$example_dir" -name "*.fna" -type f 2>/dev/null))
        local faa_files=($(find "$example_dir" -name "*.faa" -type f 2>/dev/null))
        
        print_success "示例数据目录存在: $example_dir"
        print_info "  FNA文件数: ${#fna_files[@]}"
        print_info "  FAA文件数: ${#faa_files[@]}"
        
        if [[ ${#fna_files[@]} -gt 0 || ${#faa_files[@]} -gt 0 ]]; then
            print_success "找到示例数据文件"
        else
            print_warning "示例数据目录为空"
        fi
    else
        print_warning "示例数据目录不存在: $example_dir"
    fi
}

# 检查Python环境
check_python_environment() {
    print_info "检查Python环境..."
    
    # 检查Python版本
    if command -v python3 &>/dev/null; then
        local python_version=$(python3 --version 2>&1 | cut -d' ' -f2)
        print_success "Python3版本: $python_version"
    else
        print_error "未找到Python3"
        return 1
    fi
    
    # 检查pandas
    if python3 -c "import pandas" &>/dev/null; then
        local pandas_version=$(python3 -c "import pandas; print(pandas.__version__)" 2>/dev/null)
        print_success "Pandas版本: $pandas_version"
    else
        print_warning "未找到pandas包，后处理脚本可能无法运行"
        print_info "安装命令: pip3 install pandas"
    fi
    
    # 检查其他可选包
    local optional_packages=("numpy" "matplotlib" "seaborn")
    for package in "${optional_packages[@]}"; do
        if python3 -c "import $package" &>/dev/null; then
            print_success "可选包 $package 已安装"
        else
            print_warning "可选包 $package 未安装"
        fi
    done
}

# 生成软件路径配置
generate_path_config() {
    print_info "生成软件路径配置..."
    
    local config_file="${SCRIPT_DIR}/software_paths.conf"
    
    # 查找软件路径
    local spacedust_bin=""
    local prodigal_bin=""
    local foldseek_bin=""
    
    # Spacedust
    for path in "${DOWNLOAD_DIR}/spacedust/bin/spacedust" "${DOWNLOAD_DIR}/spacedust"; do
        if [[ -x "$path" ]]; then
            spacedust_bin="$path"
            break
        fi
    done
    
    # Prodigal
    for path in "${DOWNLOAD_DIR}/prodigal" "${DOWNLOAD_DIR}/prodigal/prodigal"; do
        if [[ -x "$path" ]]; then
            prodigal_bin="$path"
            break
        fi
    done
    
    # Foldseek
    for path in "${DOWNLOAD_DIR}/foldseek/bin/foldseek" "${DOWNLOAD_DIR}/foldseek"; do
        if [[ -x "$path" ]]; then
            foldseek_bin="$path"
            break
        fi
    done
    
    # 写入配置文件
    cat > "$config_file" << EOF
# Spacedust 软件路径配置文件
# 由 setup_tools.sh 自动生成

# 软件可执行文件路径
SPACEDUST_BIN="$spacedust_bin"
PRODIGAL_BIN="$prodigal_bin"
FOLDSEEK_BIN="$foldseek_bin"

# 目录路径
DOWNLOAD_DIR="$DOWNLOAD_DIR"
DATABASE_DIR="$DATABASE_DIR"
BASE_DIR="$BASE_DIR"

# 数据库路径
KEGG_DATABASE_PATH="$DATABASE_DIR/KEGG_70/keggclusterdb"

# 生成时间
GENERATED_TIME="$(date '+%Y-%m-%d %H:%M:%S')"
EOF
    
    print_success "软件路径配置已生成: $config_file"
}

# 显示系统信息
show_system_info() {
    print_info "系统信息..."
    
    echo "  操作系统: $(uname -s)"
    echo "  内核版本: $(uname -r)"
    echo "  硬件架构: $(uname -m)"
    
    if command -v nproc &>/dev/null; then
        echo "  CPU核心数: $(nproc)"
    fi
    
    if command -v free &>/dev/null; then
        local mem_info=$(free -h | grep "Mem:" | awk '{print $2}')
        echo "  内存大小: $mem_info"
    fi
    
    echo "  当前用户: $(whoami)"
    echo "  工作目录: $(pwd)"
}

# 主函数
main() {
    echo -e "${BLUE}=== Spacedust 工具设置检查 ===${NC}"
    echo
    
    show_system_info
    echo
    
    check_directory_structure
    echo
    
    check_spacedust
    echo
    
    check_prodigal
    echo
    
    check_foldseek
    echo
    
    check_databases
    echo
    
    check_example_data
    echo
    
    check_python_environment
    echo
    
    generate_path_config
    echo
    
    echo -e "${GREEN}=== 检查完成 ===${NC}"
    echo -e "${GREEN}如有警告或错误，请根据提示进行修复${NC}"
    echo -e "${GREEN}运行示例分析: ${SCRIPT_DIR}/run_example.sh${NC}"
}

# 运行主函数
main "$@"