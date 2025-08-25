#!/bin/bash

# 修复版：仅运行 FastQC 的基因组数据质控脚本
# 解决 Java 环境问题

echo "🧬 FastQC 质控启动 (修复版)"
echo "=================================="

# ===== 路径设置 =====
BASENAME="ERR197551"
raw_data_dir="/mnt/c/Users/Administrator/Desktop/${BASENAME}"
read1="${raw_data_dir}/${BASENAME}_1.fastq.gz"
read2="${raw_data_dir}/${BASENAME}_2.fastq.gz"
THREADS=8

# 输出目录
qc_dir="/mnt/c/Users/Administrator/Desktop/${BASENAME}/QC"
mkdir -p "$qc_dir"
cd "$qc_dir" || { echo "❌ 无法进入目录: $qc_dir"; exit 1; }

echo "📁 质控目录: $qc_dir"

# ===== 输入检查 =====
if [[ ! -f "$read1" ]] || [[ ! -f "$read2" ]]; then
    echo "❌ 输入文件不存在:"
    echo "   $read1"
    echo "   $read2"
    exit 1
fi

echo "✅ 输入文件检查通过"
echo "   Read1: $read1"
echo "   Read2: $read2"

# ===== Java 环境修复 =====
echo ""
echo "=== Java 环境设置 ==="

# 暂时退出 conda 环境使用系统 Java
if [[ -n "$CONDA_DEFAULT_ENV" ]]; then
    echo "🔧 检测到 conda 环境: $CONDA_DEFAULT_ENV"
    echo "💡 将使用系统级 Java 和 FastQC 来避免环境冲突"
    
    # 保存当前conda环境
    CURRENT_CONDA_ENV="$CONDA_DEFAULT_ENV"
    
    # 临时使用系统路径
    export PATH="/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin:$PATH"
    
    # 确保使用系统 Java
    export JAVA_HOME=""
fi

# 检查 Java 是否工作
echo "🔍 检查 Java 环境..."
if ! java -version 2>&1 | grep -q "version"; then
    echo "❌ Java 环境仍有问题，尝试备用方案..."
    
    # 尝试直接找到工作的 Java
    for java_path in /usr/bin/java /usr/lib/jvm/*/bin/java; do
        if [[ -x "$java_path" ]] && "$java_path" -version >/dev/null 2>&1; then
            export JAVA_HOME="$(dirname $(dirname $java_path))"
            export PATH="$(dirname $java_path):$PATH"
            echo "✅ 找到工作的 Java: $java_path"
            break
        fi
    done
fi

# ===== FastQC 检查 =====
echo ""
echo "=== 步骤: FastQC质量检查 ==="

# 确保使用系统的 FastQC
FASTQC_CMD="/usr/bin/fastqc"
if [[ ! -x "$FASTQC_CMD" ]]; then
    FASTQC_CMD="fastqc"
fi

if command -v "$FASTQC_CMD" &>/dev/null; then
    echo "🔧 运行FastQC..."
    echo "📍 使用 FastQC: $(which $FASTQC_CMD)"
    echo "📍 使用 Java: $(which java)"
    
    mkdir -p fastqc_raw_output

    echo "📊 分析原始数据质量..."
    
    # 使用 timeout 防止卡死，并且显示详细输出
    timeout 600s "$FASTQC_CMD" "$read1" "$read2" -o fastqc_raw_output --threads "$THREADS" --extract 2>&1
    fastqc_exit=$?

    if [[ $fastqc_exit -eq 0 ]]; then
        echo "✅ FastQC分析完成"
        echo "📁 结果位置: $qc_dir/fastqc_raw_output/"
        
        # 列出生成的文件
        echo "📋 生成的报告文件:"
        ls -la fastqc_raw_output/*.html 2>/dev/null || echo "   (未找到HTML报告)"
        
    elif [[ $fastqc_exit -eq 124 ]]; then
        echo "⚠️  FastQC运行超时，进行基础统计兜底..."
    else
        echo "⚠️  FastQC运行失败(退出码: $fastqc_exit)，进行基础统计兜底..."
    fi

    # ===== 基础统计兜底（无论FastQC成功与否都运行） =====
    echo ""
    echo "=== 基础序列统计 ==="
    
    # 计算序列条数
    echo "📊 计算序列统计信息..."
    read1_lines=$(zcat "$read1" 2>/dev/null | wc -l)
    read2_lines=$(zcat "$read2" 2>/dev/null | wc -l)
    
    if [[ -z "$read1_lines" || -z "$read2_lines" || "$read1_lines" -eq 0 || "$read2_lines" -eq 0 ]]; then
        echo "❌ 无法读取压缩文件内容，请检查文件完整性。"
    else
        read1_seqs=$((read1_lines / 4))
        read2_seqs=$((read2_lines / 4))

        # 读长估计（取R1首条序列）
        rl=$(zcat "$read1" | sed -n '2p' | wc -c)
        read_length=$((rl > 0 ? rl - 1 : 0))

        # 文件大小
        read1_size=$(ls -lh "$read1" | awk '{print $5}')
        read2_size=$(ls -lh "$read2" | awk '{print $5}')

        echo "📊 序列统计结果:"
        echo "   Read1 序列数: $read1_seqs"
        echo "   Read2 序列数: $read2_seqs"
        echo "   读长(估计): ${read_length} bp"
        echo "   文件大小: R1=$read1_size, R2=$read2_size"
        if [[ $read1_seqs -eq $read2_seqs ]]; then
            echo "   数据完整性检查: ✅ 配对完整"
        else
            echo "   数据完整性检查: ⚠️ 配对不完整"
        fi
        
        # 估算覆盖度（假设基因组大小4Mb）
        total_bases=$((read1_seqs * read_length * 2))
        coverage=$(echo "scale=1; $total_bases / 4000000" | bc 2>/dev/null || echo "计算失败")
        echo "   估算覆盖度: ${coverage}x (假设基因组4Mb)"
    fi

else
    echo "❌ FastQC未找到"
    echo "请检查 FastQC 安装: sudo apt install fastqc 或 conda install -c bioconda fastqc"
fi

# ===== 结果整理和报告生成 =====
echo ""
echo "=== 生成质控汇总报告 ==="

# 创建汇总报告文件
SUMMARY_CSV="$qc_dir/quality_control_summary.csv"
SUMMARY_TXT="$qc_dir/quality_control_summary.txt"

# 解析FastQC HTML报告（如果存在）
parse_fastqc_reports() {
    local data_files=($(find fastqc_raw_output -name "fastqc_data.txt" 2>/dev/null || echo ""))
    
    if [[ ${#data_files[@]} -eq 0 ]]; then
        echo "⚠️  未找到FastQC数据文件"
        return 1
    fi
    
    echo "📊 解析FastQC报告..."
    
    # CSV表头
    echo "Sample,File_Type,Total_Sequences,Sequences_flagged_as_poor_quality,Sequence_length,GC_content,Basic_Statistics,Per_base_sequence_quality,Per_tile_sequence_quality,Per_sequence_quality_scores,Per_base_sequence_content,Per_sequence_GC_content,Per_base_N_content,Sequence_Length_Distribution,Sequence_Duplication_Levels,Overrepresented_sequences,Adapter_Content" > "$SUMMARY_CSV"
    
    for data_file in "${data_files[@]}"; do
        if [[ -f "$data_file" ]]; then
            echo "   解析: $(basename "$(dirname "$data_file")")"
            parse_single_fastqc_data "$data_file" >> "$SUMMARY_CSV"
        fi
    done
    
    return 0
}

# 解析单个FastQC数据文件
parse_single_fastqc_data() {
    local data_file="$1"
    local sample_name=$(basename "$(dirname "$data_file")")
    local file_type="Unknown"
    
    # 判断文件类型
    if [[ "$sample_name" == *"_1_"* ]] || [[ "$sample_name" == *"R1"* ]]; then
        file_type="Read1"
    elif [[ "$sample_name" == *"_2_"* ]] || [[ "$sample_name" == *"R2"* ]]; then
        file_type="Read2"
    fi
    
    # 提取基本统计信息
    local total_seq=$(grep "Total Sequences" "$data_file" | cut -f2 || echo "N/A")
    local poor_qual=$(grep "Sequences flagged as poor quality" "$data_file" | cut -f2 || echo "N/A")
    local seq_length=$(grep "^Sequence length" "$data_file" | cut -f2 || echo "N/A")
    local gc_content=$(grep "^%GC" "$data_file" | cut -f2 || echo "N/A")
    
    # 提取各项检查结果（从模块状态行）
    local basic_stats=$(grep ">>Basic Statistics" "$data_file" | awk '{print $3}' || echo "N/A")
    local per_base_qual=$(grep ">>Per base sequence quality" "$data_file" | awk '{print $5}' || echo "N/A")
    local per_tile_qual=$(grep ">>Per tile sequence quality" "$data_file" | awk '{print $5}' || echo "N/A")
    local per_seq_qual=$(grep ">>Per sequence quality scores" "$data_file" | awk '{print $5}' || echo "N/A")
    local per_base_content=$(grep ">>Per base sequence content" "$data_file" | awk '{print $5}' || echo "N/A")
    local per_seq_gc=$(grep ">>Per sequence GC content" "$data_file" | awk '{print $5}' || echo "N/A")
    local per_base_n=$(grep ">>Per base N content" "$data_file" | awk '{print $5}' || echo "N/A")
    local seq_length_dist=$(grep ">>Sequence Length Distribution" "$data_file" | awk '{print $4}' || echo "N/A")
    local seq_dup=$(grep ">>Sequence Duplication Levels" "$data_file" | awk '{print $4}' || echo "N/A")
    local overrep_seq=$(grep ">>Overrepresented sequences" "$data_file" | awk '{print $3}' || echo "N/A")
    local adapter_content=$(grep ">>Adapter Content" "$data_file" | awk '{print $3}' || echo "N/A")
    
    # 输出CSV行
    echo "$sample_name,$file_type,$total_seq,$poor_qual,$seq_length,$gc_content,$basic_stats,$per_base_qual,$per_tile_qual,$per_seq_qual,$per_base_content,$per_seq_gc,$per_base_n,$seq_length_dist,$seq_dup,$overrep_seq,$adapter_content"
}

# 生成文本格式汇总报告
generate_text_summary() {
    echo "📝 生成文本格式汇总报告..."
    
    {
        echo "========================================"
        echo "       基因组数据质控汇总报告"
        echo "========================================"
        echo "样本名称: $BASENAME"
        echo "分析时间: $(date)"
        echo "分析工具: FastQC + 自定义统计"
        echo ""
        
        echo "--- 基础序列统计 ---"
        if [[ -n "$read1_seqs" ]]; then
            echo "Read1 序列数: $read1_seqs"
            echo "Read2 序列数: $read2_seqs"
            echo "读长(估计): ${read_length} bp"
            echo "文件大小: R1=$read1_size, R2=$read2_size"
            echo "数据配对: $([ $read1_seqs -eq $read2_seqs ] && echo "完整" || echo "不完整")"
            if [[ -n "$coverage" ]]; then
                echo "估算覆盖度: ${coverage}x (基于4Mb基因组)"
            fi
        fi
        echo ""
        
        if [[ -f "$SUMMARY_CSV" ]]; then
            echo "--- FastQC 质量检查结果 ---"
            
            # 如果CSV文件存在，解析并显示关键信息
            while IFS=',' read -r sample file_type total_seq poor_qual seq_len gc basic per_base_qual per_tile per_seq per_base_content per_seq_gc per_base_n seq_len_dist seq_dup overrep adapter; do
                if [[ "$sample" != "Sample" ]]; then  # 跳过表头
                    echo "文件: $sample ($file_type)"
                    echo "  总序列数: $total_seq"
                    echo "  低质量序列: $poor_qual"
                    echo "  序列长度: $seq_len"
                    echo "  GC含量: $gc"
                    echo "  质量检查状态:"
                    echo "    基础统计: $basic"
                    echo "    每碱基质量: $per_base_qual"
                    echo "    每序列质量: $per_seq_qual"
                    echo "    碱基组成: $per_base_content"
                    echo "    GC分布: $per_seq_gc"
                    echo "    序列重复: $seq_dup"
                    echo "    接头污染: $adapter"
                    
                    # 质量评估
                    local issues=0
                    [[ "$per_base_qual" == "FAIL" ]] && ((issues++))
                    [[ "$per_seq_qual" == "FAIL" ]] && ((issues++))
                    [[ "$adapter" == "FAIL" ]] && ((issues++))
                    
                    if [[ $issues -eq 0 ]]; then
                        echo "  整体评估: ✅ 质量良好"
                    elif [[ $issues -le 2 ]]; then
                        echo "  整体评估: ⚠️  轻微问题，建议检查"
                    else
                        echo "  整体评估: ❌ 需要清理处理"
                    fi
                    echo ""
                fi
            done < "$SUMMARY_CSV"
        fi
        
        echo "--- 建议和下一步 ---"
        if [[ $fastqc_exit -eq 0 ]]; then
            echo "✅ FastQC分析成功完成"
            echo "🔍 请检查详细的HTML报告以获得更多信息"
            
            # 根据结果给出建议
            if [[ -f "$SUMMARY_CSV" ]]; then
                local has_adapter_issues=$(grep -c "FAIL" "$SUMMARY_CSV" | head -1 || echo "0")
                if [[ $has_adapter_issues -gt 0 ]]; then
                    echo "💡 建议使用trimmomatic/fastp进行接头去除和质量修剪"
                fi
            fi
        else
            echo "⚠️  FastQC分析失败，但基础统计可用"
            echo "💡 可以尝试使用fastp作为替代质控工具"
        fi
        
        echo ""
        echo "--- 输出文件 ---"
        echo "📁 HTML报告: fastqc_raw_output/"
        echo "📊 CSV汇总: quality_control_summary.csv"
        echo "📝 文本报告: quality_control_summary.txt"
        
    } > "$SUMMARY_TXT"
}

# 执行报告生成
if [[ $fastqc_exit -eq 0 ]]; then
    if parse_fastqc_reports; then
        echo "✅ FastQC报告解析完成"
    else
        echo "⚠️  FastQC报告解析失败，仅生成基础统计"
    fi
fi

generate_text_summary
echo "✅ 汇总报告生成完成"

echo ""
echo "=== 总结 ==="
if [[ $fastqc_exit -eq 0 ]]; then
    echo "✅ 原始数据FastQC分析: 完成"
else
    echo "⚠️  原始数据FastQC分析: 失败，但已提供基础统计"
fi
echo ""
echo "📁 输出文件:"
echo "   - HTML详细报告: fastqc_raw_output/"
echo "   - CSV汇总数据: quality_control_summary.csv"
echo "   - 文本汇总报告: quality_control_summary.txt"
echo ""
echo "🎯 下一步建议:"
echo "1. 查看 quality_control_summary.txt 了解数据质量概况"
echo "2. 检查 quality_control_summary.csv 进行批量分析"
echo "3. 查看 fastqc_raw_output 中的HTML报告获取详细信息"
echo "4. 根据质量评估决定是否需要数据清理"
echo ""
echo "🏁 完成"
