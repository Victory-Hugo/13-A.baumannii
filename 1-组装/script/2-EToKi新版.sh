#!/bin/bash

# 批量使用 EToKi 的基因组组装脚本（自动检测单端/双端测序）

echo "🧬 基因组组装流程启动（EToKi - 批量处理）"
echo "=============================================="

# ===== 配置参数 =====
INPUT_DIR="/data_raid/7_luolintao/1_Baoman/2-Sequence/FASTQ/FASTQ/"
OUTPUT_DIR="/data_raid/7_luolintao/1_Baoman/2-Sequence/FASTQ/Assemble/"
PARALLEL_JOBS=15

# 导出变量以便在parallel中使用
export INPUT_DIR OUTPUT_DIR

# 检查输入目录是否存在
if [[ ! -d "$INPUT_DIR" ]]; then
    echo "❌ 输入目录不存在: $INPUT_DIR"
    exit 1
fi

# 创建输出目录
mkdir -p "$OUTPUT_DIR"

echo "📁 输入目录: $INPUT_DIR"
echo "📁 输出目录: $OUTPUT_DIR"
echo "⚙️  并行任务数: $PARALLEL_JOBS"

# ===== 函数：处理单个样本 =====
process_sample() {
    local input_file="$1"
    local basename=$(basename "$input_file" .fastq.gz)
    local assembly_dir="$OUTPUT_DIR/${basename}_Assembly"
    local FINAL_FASTA="$OUTPUT_DIR/${basename}.fasta"
    
    echo "🔄 开始处理: $basename"
    echo "🔍 调试信息:"
    echo "   INPUT_DIR: $INPUT_DIR"
    echo "   OUTPUT_DIR: $OUTPUT_DIR"
    echo "   assembly_dir: $assembly_dir"
    echo "   FINAL_FASTA: $FINAL_FASTA"
    
    # 检查是否为双端测序
    local read1="$input_file"
    local read2=""
    local is_paired=false
    
    # 尝试查找配对文件（各种可能的命名格式）
    if [[ "$basename" =~ _1$ ]]; then
        # 如果文件名以_1结尾，查找对应的_2文件
        local base_prefix="${basename%_1}"
        read2="${INPUT_DIR}/${base_prefix}_2.fastq.gz"
        if [[ -f "$read2" ]]; then
            is_paired=true
            basename="$base_prefix"
        fi
    elif [[ "$basename" =~ _R1$ ]]; then
        # 如果文件名以_R1结尾，查找对应的_R2文件
        local base_prefix="${basename%_R1}"
        read2="${INPUT_DIR}/${base_prefix}_R2.fastq.gz"
        if [[ -f "$read2" ]]; then
            is_paired=true
            basename="$base_prefix"
        fi
    else
        # 检查是否存在同名的_1/_2或_R1/_R2文件
        if [[ -f "${INPUT_DIR}/${basename}_1.fastq.gz" && -f "${INPUT_DIR}/${basename}_2.fastq.gz" ]]; then
            read1="${INPUT_DIR}/${basename}_1.fastq.gz"
            read2="${INPUT_DIR}/${basename}_2.fastq.gz"
            is_paired=true
        elif [[ -f "${INPUT_DIR}/${basename}_R1.fastq.gz" && -f "${INPUT_DIR}/${basename}_R2.fastq.gz" ]]; then
            read1="${INPUT_DIR}/${basename}_R1.fastq.gz"
            read2="${INPUT_DIR}/${basename}_R2.fastq.gz"
            is_paired=true
        fi
    fi
    
    # 更新路径变量
    assembly_dir="$OUTPUT_DIR/${basename}_Assembly"
    FINAL_FASTA="$OUTPUT_DIR/${basename}.fasta"
    
    if [[ "$is_paired" == true ]]; then
        echo "✅ 检测到双端测序: $basename"
        echo "   Read1: $read1"
        echo "   Read2: $read2"
    else
        echo "✅ 检测到单端测序: $basename"
        echo "   Read: $read1"
    fi

    
    # 检查输入文件是否存在
    if [[ ! -f "$read1" ]]; then
        echo "❌ 输入文件不存在: $read1"
        return 1
    fi
    
    if [[ "$is_paired" == true && ! -f "$read2" ]]; then
        echo "❌ 配对文件不存在: $read2"
        return 1
    fi
    
    # ===== 组装目录 =====
    mkdir -p "$assembly_dir"
    cd "$assembly_dir" || { echo "❌ 无法进入目录: $assembly_dir"; return 1; }
    echo "📁 组装目录: $assembly_dir"
    
    # ===== EToKi 流程 =====
    echo ""
    echo "=== 执行：EToKi 综合流程 ($basename) ==="
    
    # 检查 EToKi
    if ! command -v EToKi.py &>/dev/null; then
        echo "❌ EToKi 未安装，请先安装"
        echo "安装命令: conda install -c bioconda etoki"
        return 1
    fi
    
    mkdir -p etoki_assembly
    cd etoki_assembly || { echo "❌ 无法进入目录: etoki_assembly"; return 1; }
    
    # 可配置前缀（用于 EToKi 输出文件命名）
    prefix=${basename}
    
    # 步骤1：EToKi 数据预处理
    echo "📊 EToKi 数据预处理 ($basename)..."
    if [[ "$is_paired" == true ]]; then
        # 双端测序
        time EToKi.py prepare \
            --pe "$read1","$read2" \
            --prefix "${prefix}_cleaned" 2>&1 | tee etoki_prepare.log
    else
        # 单端测序
        time EToKi.py prepare \
            --se "$read1" \
            --prefix "${prefix}_cleaned" 2>&1 | tee etoki_prepare.log
    fi
    
    if [[ ${PIPESTATUS[0]} -ne 0 ]]; then
        echo "❌ EToKi 数据预处理失败 ($basename)，查看日志: etoki_prepare.log"
        return 1
    fi
    echo "✅ 预处理完成 ($basename)"
    
    # 预处理后 EToKi 规范的文件名称
    if [[ "$is_paired" == true ]]; then
        R1="${prefix}_cleaned_L1_R1.fastq.gz"
        R2="${prefix}_cleaned_L1_R2.fastq.gz"
        if [[ ! -f "$R1" || ! -f "$R2" ]]; then
            echo "❌ 未找到预处理输出: $R1 / $R2"
            echo "请检查 etoki_prepare.log"
            return 1
        fi
        PE_OPTION="--pe $R1,$R2"
    else
        SE="${prefix}_cleaned_L1_SE.fastq.gz"
        if [[ ! -f "$SE" ]]; then
            echo "❌ 未找到预处理输出: $SE"
            echo "请检查 etoki_prepare.log"
            return 1
        fi
        PE_OPTION="--se $SE"
    fi
    
    # 步骤2：EToKi 组装
    echo "🔧 EToKi 基因组组装 ($basename)..."
    time EToKi.py assemble \
        $PE_OPTION \
        --prefix "${prefix}_assembly" \
        --assembler spades \
        --kraken \
        --accurate_depth 2>&1 | tee etoki_assembly.log
    
    if [[ ${PIPESTATUS[0]} -ne 0 ]]; then
        echo "❌ EToKi 组装失败 ($basename)，查看日志: etoki_assembly.log"
        return 1
    fi
    
    echo "✅ 组装完成 ($basename)"
    
    # 检查并移动组装结果文件
    if [[ -f "${prefix}_assembly/etoki.mapping.reference.fasta" ]]; then
        mv "${prefix}_assembly/etoki.mapping.reference.fasta" "$FINAL_FASTA"
        echo "📄 组装结果保存至: $FINAL_FASTA"
    elif [[ -f "${prefix}_assembly/spades/contigs.fasta" ]]; then
        cp "${prefix}_assembly/spades/contigs.fasta" "$FINAL_FASTA"
        echo "📄 组装结果保存至: $FINAL_FASTA (来自spades contigs)"
    else
        echo "⚠️ 未找到预期的组装结果文件 ($basename)"
        return 1
    fi
    
    # 删除不必要的中间文件
    rm -rf "${assembly_dir}/etoki_assembly/${prefix}_assembly/spades/"
    rm -f "${assembly_dir}/etoki_assembly/${prefix}_assembly/"*.fastq.gz
    rm -f "${assembly_dir}/etoki_assembly/"*.fastq.gz
    rm -f "${assembly_dir}/etoki_assembly/${prefix}_assembly/"*.bam "${assembly_dir}/etoki_assembly/${prefix}_assembly/"*.bai
    echo "🗑️ 删除中间文件完成 ($basename)"
    
    echo "✅ 样本 $basename 处理完成"
    return 0
}

# 导出函数以便在并行处理中使用
export -f process_sample

# ===== 主流程 =====
echo ""
echo "=== 扫描输入文件 ==="

# 获取所有fastq.gz文件
mapfile -t all_files < <(find "$INPUT_DIR" -name "*.fastq.gz" -type f | sort)

if [[ ${#all_files[@]} -eq 0 ]]; then
    echo "❌ 在 $INPUT_DIR 中未找到任何 .fastq.gz 文件"
    exit 1
fi

echo "📊 找到 ${#all_files[@]} 个 fastq.gz 文件"

# 过滤掉已经处理过的配对文件（避免重复处理_2文件）
declare -a files_to_process=()
declare -A processed_bases=()

for file in "${all_files[@]}"; do
    basename=$(basename "$file" .fastq.gz)
    
    # 检查是否为_2或_R2文件
    if [[ "$basename" =~ _2$ ]] || [[ "$basename" =~ _R2$ ]]; then
        # 这是第二个读取文件，检查是否已经处理了对应的第一个文件
        if [[ "$basename" =~ _2$ ]]; then
            base_prefix="${basename%_2}"
        else
            base_prefix="${basename%_R2}"
        fi
        
        if [[ -n "${processed_bases[$base_prefix]}" ]]; then
            echo "⏭️  跳过 $basename (已作为 ${base_prefix} 的配对文件处理)"
            continue
        fi
    fi
    
    # 检查是否为_1或_R1文件，或者单端文件
    if [[ "$basename" =~ _1$ ]]; then
        base_prefix="${basename%_1}"
        processed_bases[$base_prefix]=1
    elif [[ "$basename" =~ _R1$ ]]; then
        base_prefix="${basename%_R1}"
        processed_bases[$base_prefix]=1
    else
        # 单端文件或其他命名格式
        processed_bases[$basename]=1
    fi
    
    files_to_process+=("$file")
done

echo "📋 待处理的文件数量: ${#files_to_process[@]}"
for file in "${files_to_process[@]}"; do
    echo "   - $(basename "$file")"
done

echo ""
echo "=== 开始并行处理 (并行度: $PARALLEL_JOBS) ==="

# 使用GNU parallel进行并行处理
if command -v parallel &>/dev/null; then
    printf '%s\n' "${files_to_process[@]}" | parallel --unsafe -j "$PARALLEL_JOBS" process_sample {}
    parallel_exit_code=$?
else
    echo "❌ GNU parallel 未安装，将串行处理"
    parallel_exit_code=0
    for file in "${files_to_process[@]}"; do
        process_sample "$file"
        if [[ $? -ne 0 ]]; then
            parallel_exit_code=1
            echo "⚠️ 处理 $file 时出现错误，继续处理下一个文件"
        fi
    done
fi

# ===== 总结 =====
echo ""
echo "=== 批量组装完成总结 ==="
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📁 输入目录: $INPUT_DIR"
echo "� 输出目录: $OUTPUT_DIR"
echo "📊 处理文件数: ${#files_to_process[@]}"

echo ""
echo "📄 输出文件列表:"
successful_assemblies=0
for file in "${files_to_process[@]}"; do
    basename=$(basename "$file" .fastq.gz)
    
    # 处理配对文件的basename
    if [[ "$basename" =~ _1$ ]]; then
        basename="${basename%_1}"
    elif [[ "$basename" =~ _R1$ ]]; then
        basename="${basename%_R1}"
    fi
    
    output_fasta="$OUTPUT_DIR/${basename}.fasta"
    if [[ -f "$output_fasta" ]]; then
        echo "   ✅ $output_fasta"
        ((successful_assemblies++))
    else
        echo "   ❌ $output_fasta (组装失败或未完成)"
    fi
done

echo ""
echo "📊 成功组装: $successful_assemblies/${#files_to_process[@]}"

if [[ $parallel_exit_code -eq 0 && $successful_assemblies -eq ${#files_to_process[@]} ]]; then
    echo "🎉 所有样本组装成功！"
else
    echo "⚠️ 部分样本组装失败，请检查日志文件"
fi

echo ""
echo "🎯 后续建议:"
echo "1. 质量评估: quast.py $OUTPUT_DIR/*.fasta"
echo "2. 完整性检查: checkm lineage_wf -t 8 -x fasta $OUTPUT_DIR checkm_output"
echo "3. 污染检测: 对每个fasta文件运行kraken2"
echo "4. 基因注释: 对每个fasta文件运行prokka"

echo ""
echo "🏁 基因组组装流程完成（EToKi-批量处理）！"
