#!/bin/bash

# 高质量组装问题诊断与解决方案
# 针对ERR197551数据的深度优化


# 设置路径
raw_data_dir="/mnt/c/Users/Administrator/Desktop/ERR197551"
read1="${raw_data_dir}/ERR197551_1.fastq.gz"
read2="${raw_data_dir}/ERR197551_2.fastq.gz"

# 创建新的分析目录
analysis_dir="/mnt/c/Users/Administrator/Desktop/ERR197551_advanced_analysis"
mkdir -p "$analysis_dir"
cd "$analysis_dir"

echo "📁 分析目录: $analysis_dir"

echo ""
echo "=== 步骤1: 数据质量深度检查 ==="

# 使用FastQC进行质量评估
if command -v fastqc &>/dev/null; then
    echo "🔧 运行FastQC质量检查..."
    mkdir -p fastqc_output
    fastqc "$read1" "$read2" -o fastqc_output --threads 8
    echo "✅ FastQC完成，结果在 fastqc_output/"
else
    echo "⚠️  FastQC未安装，跳过质量检查"
fi

echo ""
echo "=== 步骤2: 序列去重和过滤 ==="

# 使用BBTools进行更严格的数据预处理
if command -v bbduk.sh &>/dev/null; then
    echo "🔧 使用BBTools进行数据清理..."
    
    # 去除接头、低质量序列和重复
    bbduk.sh \
        in1="$read1" \
        in2="$read2" \
        out1=cleaned_1.fastq.gz \
        out2=cleaned_2.fastq.gz \
        ref=adapters \
        ktrim=r k=23 mink=11 hdist=1 tpe tbo \
        qtrim=rl trimq=20 \
        minlen=50 \
        threads=8
    
    echo "✅ 数据清理完成"
    cleaned_read1="cleaned_1.fastq.gz"
    cleaned_read2="cleaned_2.fastq.gz"
else
    echo "⚠️  BBTools未安装，使用原始数据"
    cleaned_read1="$read1"
    cleaned_read2="$read2"
fi

echo ""
echo "=== 步骤3: 多种高级组装策略 ==="

# 策略A: SPAdes + 严格参数
echo "🔧 策略A: SPAdes最严格参数..."
mkdir -p strategyA_strict
spades.py \
    --isolate \
    --only-assembler \
    --pe1-1 "$cleaned_read1" \
    --pe1-2 "$cleaned_read2" \
    --threads 8 \
    --memory 16 \
    -k 21,33,55,77 \
    -o strategyA_strict

# 策略B: 使用覆盖度过滤
echo "🔧 策略B: SPAdes + 覆盖度过滤..."
mkdir -p strategyB_coverage
spades.py \
    --isolate \
    --pe1-1 "$cleaned_read1" \
    --pe1-2 "$cleaned_read2" \
    --threads 8 \
    --memory 16 \
    --cov-cutoff 15 \
    -k 21,33,55 \
    -o strategyB_coverage

# 策略C: MEGAHIT (适合高覆盖度数据)
if command -v megahit &>/dev/null; then
    echo "🔧 策略C: MEGAHIT组装..."
    megahit \
        -1 "$cleaned_read1" \
        -2 "$cleaned_read2" \
        -o strategyC_megahit \
        --threads 8 \
        --min-contig-len 500 \
        --k-min 21 \
        --k-max 77 \
        --k-step 10
else
    echo "⚠️  MEGAHIT未安装，跳过策略C"
fi

echo ""
echo "=== 步骤4: 结果对比分析 ==="

echo "📊 各策略组装结果对比:"
echo "策略 | Contigs数 | 基因组大小 | 最长Contig | N50"

for strategy in "strategyA_strict" "strategyB_coverage" "strategyC_megahit"; do
    if [[ "$strategy" == "strategyC_megahit" ]]; then
        contigs_file="$strategy/final.contigs.fa"
    else
        contigs_file="$strategy/contigs.fasta"
    fi
    
    if [[ -f "$contigs_file" ]]; then
        contigs_count=$(grep "^>" "$contigs_file" | wc -l)
        genome_size=$(grep -v "^>" "$contigs_file" | tr -d '\n' | wc -c)
        longest_contig=$(grep "^>" "$contigs_file" | head -1 | grep -o "length_[0-9]*" | cut -d'_' -f2 2>/dev/null || echo "N/A")
        
        # 简单N50计算
        grep -v "^>" "$contigs_file" | tr -d '\n' > temp_seq.txt
        total_length=$(wc -c < temp_seq.txt)
        half_length=$((total_length / 2))
        
        # 获取contig长度并排序
        if [[ "$strategy" == "strategyC_megahit" ]]; then
            grep "^>" "$contigs_file" | grep -o "len=[0-9]*" | cut -d'=' -f2 | sort -nr > lengths.tmp
        else
            grep "^>" "$contigs_file" | grep -o "length_[0-9]*" | cut -d'_' -f2 | sort -nr > lengths.tmp
        fi
        
        cumulative=0
        n50="N/A"
        while read length; do
            cumulative=$((cumulative + length))
            if [[ $cumulative -ge $half_length ]]; then
                n50=$length
                break
            fi
        done < lengths.tmp
        
        printf "%-15s | %-9s | %-10s | %-11s | %s\n" \
            "$strategy" "$contigs_count" \
            "$(echo "scale=2; $genome_size/1000000" | bc)Mb" \
            "$longest_contig" "$n50"
        
        rm -f temp_seq.txt lengths.tmp
    else
        printf "%-15s | %-9s | %-10s | %-11s | %s\n" \
            "$strategy" "FAILED" "-" "-" "-"
    fi
done

echo ""
echo "=== 步骤5: 推荐方案 ==="

# 找到最好的结果
best_strategy=""
min_contigs=999999
best_file=""

for strategy in "strategyA_strict" "strategyB_coverage" "strategyC_megahit"; do
    if [[ "$strategy" == "strategyC_megahit" ]]; then
        contigs_file="$strategy/final.contigs.fa"
    else
        contigs_file="$strategy/contigs.fasta"
    fi
    
    if [[ -f "$contigs_file" ]]; then
        contigs_count=$(grep "^>" "$contigs_file" | wc -l)
        genome_size=$(grep -v "^>" "$contigs_file" | tr -d '\n' | wc -c)
        
        # 选择contigs数量少且基因组大小合理(3.5-4.5Mb)的策略
        if [[ $contigs_count -lt $min_contigs ]] && \
           [[ $genome_size -gt 3500000 ]] && [[ $genome_size -lt 4500000 ]]; then
            min_contigs=$contigs_count
            best_strategy=$strategy
            best_file=$contigs_file
        fi
    fi
done

if [[ -n "$best_strategy" ]]; then
    echo "🏆 推荐策略: $best_strategy"
    echo "📁 最佳结果文件: $best_file"
    
    # 复制最佳结果到主目录
    cp "$best_file" "BEST_assembly_contigs.fasta"
    echo "✅ 最佳结果已复制为 BEST_assembly_contigs.fasta"
else
    echo "⚠️  所有策略的基因组大小都超出预期范围"
    echo "🔍 可能需要进一步的污染检测和去除"
fi

echo ""
echo "🎯 后续建议:"
echo "1. 使用QUAST进行详细质量评估"
echo "2. 用CheckM检查基因组完整性"
echo "3. 使用Kraken2检测潜在污染"
echo "4. 考虑使用长读长数据进行混合组装"
echo ""
echo "🏁 高级分析完成！"
