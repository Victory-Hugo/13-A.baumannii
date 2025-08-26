#!/bin/bash

# 交互式基因组组装脚本
# 支持多种组装策略选择

echo "🧬 基因组组装流程启动"
echo "=================================="

# 设置路径
qc_data_dir="/mnt/c/Users/Administrator/Desktop/ERR197551_QC"
raw_data_dir="/mnt/c/Users/Administrator/Desktop/ERR197551"

# 检查质控数据是否存在
if [[ -f "$qc_data_dir/cleaned_1.fastq.gz" ]] && [[ -f "$qc_data_dir/cleaned_2.fastq.gz" ]]; then
    read1="$qc_data_dir/cleaned_1.fastq.gz"
    read2="$qc_data_dir/cleaned_2.fastq.gz"
    echo "✅ 使用质控后的数据进行组装"
    echo "   Read1: $read1"
    echo "   Read2: $read2"
elif [[ -f "$raw_data_dir/ERR197551_1.fastq.gz" ]] && [[ -f "$raw_data_dir/ERR197551_2.fastq.gz" ]]; then
    read1="$raw_data_dir/ERR197551_1.fastq.gz"
    read2="$raw_data_dir/ERR197551_2.fastq.gz"
    echo "⚠️  未找到质控数据，使用原始数据"
    echo "   建议先运行质控脚本: ./1-质控.sh"
    echo "   Read1: $read1"
    echo "   Read2: $read2"
    
    echo ""
    read -p "是否继续使用原始数据进行组装？(y/N): " use_raw
    if [[ ! "$use_raw" =~ ^[Yy]$ ]]; then
        echo "❌ 已取消，请先运行质控流程"
        exit 1
    fi
else
    echo "❌ 未找到输入数据文件"
    echo "请确保以下路径存在数据文件:"
    echo "   质控数据: $qc_data_dir/cleaned_*.fastq.gz"
    echo "   原始数据: $raw_data_dir/ERR197551_*.fastq.gz"
    exit 1
fi

# 创建组装分析目录
assembly_dir="/mnt/c/Users/Administrator/Desktop/ERR197551_Assembly"
mkdir -p "$assembly_dir"
cd "$assembly_dir"

echo "📁 组装目录: $assembly_dir"

echo ""
echo "=== 基因组组装策略选择 ==="
echo "请选择组装策略:"
echo ""
echo "1️⃣  策略A: SPAdes严格参数组装"
echo "   - 使用 --isolate 模式"
echo "   - K-mer: 21,33,55,77"
echo "   - 适合：高质量细菌基因组组装"
echo "   - 特点：保守参数，高准确性"
echo ""
echo "2️⃣  策略B: SPAdes覆盖度过滤组装"
echo "   - 使用 --isolate 模式"
echo "   - K-mer: 21,33,55"
echo "   - 覆盖度过滤: ≥10x"
echo "   - 适合：去除低覆盖度噪音"
echo "   - 特点：平衡质量与连续性"
echo ""
echo "3️⃣  策略C: EToKi综合流程"
echo "   - 包含数据预处理和组装"
echo "   - 使用SPAdes作为核心组装器"
echo "   - 集成质量控制和污染检测"
echo "   - 适合：标准化流程，全面分析"
echo "   - 特点：一站式解决方案"
echo ""

# 用户选择策略
while true; do
    read -p "请输入选择 (1/2/3): " strategy_choice
    case $strategy_choice in
        1)
            strategy_name="策略A_SPAdes严格参数"
            break
            ;;
        2)
            strategy_name="策略B_SPAdes覆盖度过滤"
            break
            ;;
        3)
            strategy_name="策略C_EToKi综合流程"
            break
            ;;
        *)
            echo "❌ 无效选择，请输入 1、2 或 3"
            ;;
    esac
done

echo ""
echo "🎯 您选择了: $strategy_name"
echo "开始执行组装流程..."

case $strategy_choice in
    1)
        echo ""
        echo "=== 执行策略A: SPAdes严格参数组装 ==="
        
        # 检查SPAdes是否可用
        if ! command -v spades.py &>/dev/null; then
            echo "❌ SPAdes未安装，请先安装SPAdes"
            echo "安装命令: conda install -c bioconda spades"
            exit 1
        fi
        
        echo "🔧 运行SPAdes严格参数组装..."
        mkdir -p strategyA_strict
        
        spades.py \
            --isolate \
            --pe1-1 "$read1" \
            --pe1-2 "$read2" \
            --threads 8 \
            --memory 12 \
            -k 21,33,55,77 \
            -o strategyA_strict 2>&1 | tee strategyA_strict.log
        
        if [[ $? -eq 0 ]] && [[ -f "strategyA_strict/contigs.fasta" ]]; then
            echo "✅ 策略A组装完成"
            result_file="strategyA_strict/contigs.fasta"
            scaffolds_file="strategyA_strict/scaffolds.fasta"
        else
            echo "❌ 策略A组装失败，查看日志: strategyA_strict.log"
            exit 1
        fi
        ;;
        
    2)
        echo ""
        echo "=== 执行策略B: SPAdes覆盖度过滤组装 ==="
        
        # 检查SPAdes是否可用
        if ! command -v spades.py &>/dev/null; then
            echo "❌ SPAdes未安装，请先安装SPAdes"
            echo "安装命令: conda install -c bioconda spades"
            exit 1
        fi
        
        echo "🔧 运行SPAdes覆盖度过滤组装..."
        mkdir -p strategyB_coverage
        
        spades.py \
            --isolate \
            --pe1-1 "$read1" \
            --pe1-2 "$read2" \
            --threads 8 \
            --memory 12 \
            --cov-cutoff 10 \
            -k 21,33,55 \
            -o strategyB_coverage 2>&1 | tee strategyB_coverage.log
        
        if [[ $? -eq 0 ]] && [[ -f "strategyB_coverage/contigs.fasta" ]]; then
            echo "✅ 策略B组装完成"
            result_file="strategyB_coverage/contigs.fasta"
            scaffolds_file="strategyB_coverage/scaffolds.fasta"
        else
            echo "❌ 策略B组装失败，查看日志: strategyB_coverage.log"
            exit 1
        fi
        ;;
        
    3)
        echo ""
        echo "=== 执行策略C: EToKi综合流程 ==="
        
        # 检查EToKi是否可用
        if ! command -v EToKi.py &>/dev/null; then
            echo "❌ EToKi未安装，请先安装EToKi"
            echo "安装命令: conda install -c bioconda etoki"
            exit 1
        fi
        
        echo "🔧 运行EToKi数据预处理..."
        mkdir -p etoki_assembly
        cd etoki_assembly
        
        # 步骤1: 数据预处理
        echo "📊 EToKi数据预处理..."
        EToKi.py prepare \
            --pe "$read1","$read2" \
            --prefix ERR197551_cleaned 2>&1 | tee etoki_prepare.log
        
        if [[ $? -eq 0 ]]; then
            echo "✅ EToKi数据预处理完成"
        else
            echo "❌ EToKi数据预处理失败，查看日志: etoki_prepare.log"
            exit 1
        fi
        
        # 步骤2: 组装
        echo "🔧 EToKi基因组组装..."
        EToKi.py assemble \
            --pe ERR197551_cleaned_L1_R1.fastq.gz,ERR197551_cleaned_L1_R2.fastq.gz \
            --prefix ERR197551_assembly \
            --assembler spades \
            --kraken \
            --accurate_depth 2>&1 | tee etoki_assembly.log
        
        if [[ $? -eq 0 ]]; then
            echo "✅ EToKi组装完成"
            
            # 检查输出文件
            if [[ -f "ERR197551_assembly/etoki.mapping.reference.fasta" ]]; then
                result_file="../etoki_assembly/ERR197551_assembly/etoki.mapping.reference.fasta"
                echo "📁 主要结果: ERR197551_assembly/etoki.mapping.reference.fasta"
            elif [[ -f "ERR197551_assembly/spades/contigs.fasta" ]]; then
                result_file="../etoki_assembly/ERR197551_assembly/spades/contigs.fasta"
                echo "📁 SPAdes contigs: ERR197551_assembly/spades/contigs.fasta"
            else
                echo "⚠️  未找到预期的组装结果文件"
                result_file=""
            fi
            
            scaffolds_file="../etoki_assembly/ERR197551_assembly/spades/scaffolds.fasta"
        else
            echo "❌ EToKi组装失败，查看日志: etoki_assembly.log"
            exit 1
        fi
        
        cd "$assembly_dir"
        ;;
esac

echo ""
echo "=== 组装结果分析 ==="

if [[ -n "$result_file" ]] && [[ -f "$result_file" ]]; then
    echo "📊 组装统计分析:"
    
    # 基本统计
    contigs_count=$(grep "^>" "$result_file" | wc -l)
    genome_size=$(grep -v "^>" "$result_file" | tr -d '\n' | wc -c)
    
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📋 组装结果统计:"
    echo "   策略: $strategy_name"
    echo "   Contigs数量: $contigs_count"
    echo "   基因组大小: $(echo "scale=2; $genome_size/1000000" | bc 2>/dev/null || echo "N/A") Mb"
    
    # 获取最长contig长度
    if [[ $strategy_choice -eq 3 ]]; then
        # EToKi结果可能有不同的格式
        longest_contig=$(grep "^>" "$result_file" | head -1 | grep -o "length_[0-9]*" | cut -d'_' -f2 2>/dev/null || echo "N/A")
    else
        longest_contig=$(grep "^>" "$result_file" | grep -o "length_[0-9]*" | cut -d'_' -f2 | sort -nr | head -1 2>/dev/null || echo "N/A")
    fi
    echo "   最长Contig: $longest_contig bp"
    
    # 简单N50计算
    if [[ $strategy_choice -eq 3 ]]; then
        grep "^>" "$result_file" | grep -o "length_[0-9]*" | cut -d'_' -f2 | sort -nr > lengths.tmp 2>/dev/null
    else
        grep "^>" "$result_file" | grep -o "length_[0-9]*" | cut -d'_' -f2 | sort -nr > lengths.tmp 2>/dev/null
    fi
    
    if [[ -s lengths.tmp ]]; then
        total_length=0
        while read length; do
            if [[ -n "$length" ]] && [[ "$length" =~ ^[0-9]+$ ]]; then
                total_length=$((total_length + length))
            fi
        done < lengths.tmp
        
        half_length=$((total_length / 2))
        cumulative=0
        n50="N/A"
        
        while read length; do
            if [[ -n "$length" ]] && [[ "$length" =~ ^[0-9]+$ ]]; then
                cumulative=$((cumulative + length))
                if [[ $cumulative -ge $half_length ]]; then
                    n50=$length
                    break
                fi
            fi
        done < lengths.tmp
        
        echo "   N50: $n50 bp"
        rm -f lengths.tmp
    fi
    
    # 复制最终结果
    cp "$result_file" "final_assembly_contigs.fasta"
    echo "✅ 最终结果已复制为: final_assembly_contigs.fasta"
    
    if [[ -n "$scaffolds_file" ]] && [[ -f "$scaffolds_file" ]]; then
        cp "$scaffolds_file" "final_assembly_scaffolds.fasta"
        echo "✅ Scaffolds结果已复制为: final_assembly_scaffolds.fasta"
    fi
    
else
    echo "❌ 未找到有效的组装结果文件"
fi

echo ""
echo "=== 组装完成总结 ==="
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ 组装策略: $strategy_name"
echo "📁 组装目录: $assembly_dir"
echo "📄 主要输出文件:"
echo "   - final_assembly_contigs.fasta (主要contigs)"
if [[ -f "final_assembly_scaffolds.fasta" ]]; then
    echo "   - final_assembly_scaffolds.fasta (scaffolds)"
fi

case $strategy_choice in
    1)
        echo "   - strategyA_strict/ (完整SPAdes输出)"
        echo "   - strategyA_strict.log (运行日志)"
        ;;
    2)
        echo "   - strategyB_coverage/ (完整SPAdes输出)"
        echo "   - strategyB_coverage.log (运行日志)"
        ;;
    3)
        echo "   - etoki_assembly/ (完整EToKi输出)"
        echo "   - etoki_assembly/etoki_prepare.log (预处理日志)"
        echo "   - etoki_assembly/etoki_assembly.log (组装日志)"
        ;;
esac

echo ""
echo "🎯 后续建议:"
echo "1. 质量评估: quast.py final_assembly_contigs.fasta"
echo "2. 完整性检查: checkm lineage_wf -t 8 -x fasta . checkm_output"
echo "3. 污染检测: kraken2 --db database final_assembly_contigs.fasta"
echo "4. 基因注释: prokka --outdir annotation final_assembly_contigs.fasta"

echo ""
echo "🏁 基因组组装流程完成！"
