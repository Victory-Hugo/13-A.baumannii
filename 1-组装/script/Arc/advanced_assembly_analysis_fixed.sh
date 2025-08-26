#!/bin/bash

# 高质量组装问题诊断与解决方案 - 修复版本
# 针对ERR197551数据的深度优化

# 设置路径
raw_data_dir="/mnt/c/Users/Administrator/Desktop/ERR197551"
read1="${raw_data_dir}/ERR197551_1.fastq.gz"
read2="${raw_data_dir}/ERR197551_2.fastq.gz"

# 创建新的分析目录
analysis_dir="/mnt/c/Users/Administrator/Desktop/ERR197551_advanced_analysis_fixed"
mkdir -p "$analysis_dir"
cd "$analysis_dir"

echo "📁 分析目录: $analysis_dir"

# 检查输入文件
if [[ ! -f "$read1" ]] || [[ ! -f "$read2" ]]; then
    echo "❌ 输入文件不存在:"
    echo "   $read1"
    echo "   $read2"
    exit 1
fi

echo ""
echo "=== 步骤1: 数据质量深度检查 ==="

# 修复Java问题的FastQC运行
if command -v fastqc &>/dev/null; then
    echo "🔧 运行FastQC质量检查..."
    mkdir -p fastqc_output
    
    # 尝试使用系统Java运行FastQC
    export JAVA_HOME="/usr/lib/jvm/default-java"
    export PATH="/usr/lib/jvm/default-java/bin:$PATH"
    
    # 直接调用FastQC，绕过可能有问题的conda Java
    timeout 300s fastqc "$read1" "$read2" -o fastqc_output --threads 4 --extract || {
        echo "⚠️  FastQC运行遇到问题，尝试基础质量检查..."
        
        # 基础质量统计作为备选
        echo "📊 基础序列统计:"
        echo "Read1 行数: $(zcat "$read1" | wc -l)"
        echo "Read2 行数: $(zcat "$read2" | wc -l)"
        echo "Read1 序列数: $(($(zcat "$read1" | wc -l) / 4))"
        echo "Read2 序列数: $(($(zcat "$read2" | wc -l) / 4))"
        
        # 检查第一条序列的长度
        read_length=$(zcat "$read1" | head -2 | tail -1 | wc -c)
        echo "读长: $((read_length-1)) bp"
    }
    echo "✅ 质量检查完成"
else
    echo "⚠️  FastQC未安装，跳过质量检查"
fi

echo ""
echo "=== 步骤2: 序列去重和过滤 ==="

# 修复BBTools问题 - 直接使用原始数据或简单处理
if command -v bbduk.sh &>/dev/null; then
    echo "🔧 尝试使用BBTools进行数据清理..."
    
    # 设置较小的内存避免Java问题
    bbduk.sh \
        in1="$read1" \
        in2="$read2" \
        out1=cleaned_1.fastq.gz \
        out2=cleaned_2.fastq.gz \
        qtrim=rl \
        trimq=20 \
        minlen=50 \
        threads=4 \
        -Xmx4g 2>/dev/null
    
    if [[ -f "cleaned_1.fastq.gz" ]] && [[ -f "cleaned_2.fastq.gz" ]]; then
        echo "✅ BBTools数据清理完成"
        cleaned_read1="$(pwd)/cleaned_1.fastq.gz"
        cleaned_read2="$(pwd)/cleaned_2.fastq.gz"
    else
        echo "⚠️  BBTools失败，使用原始数据"
        cleaned_read1="$read1"
        cleaned_read2="$read2"
    fi
else
    echo "⚠️  BBTools未安装，使用原始数据"
    cleaned_read1="$read1"
    cleaned_read2="$read2"
fi

# 验证清理后的文件
echo "🔍 使用的输入文件:"
echo "   Read1: $cleaned_read1"
echo "   Read2: $cleaned_read2"
ls -lh "$cleaned_read1" "$cleaned_read2" 2>/dev/null || echo "⚠️  某些文件可能不存在"

echo ""
echo "=== 步骤3: 多种高级组装策略 ==="

# 清理之前失败的目录
echo "🧹 清理之前的组装目录..."
rm -rf strategyA_strict strategyB_coverage strategyC_megahit

# 策略A: SPAdes + 严格参数
echo "🔧 策略A: SPAdes最严格参数..."
mkdir -p strategyA_strict

if [[ -f "$cleaned_read1" ]] && [[ -f "$cleaned_read2" ]]; then
    spades.py \
        --isolate \
        --pe1-1 "$cleaned_read1" \
        --pe1-2 "$cleaned_read2" \
        --threads 8 \
        --memory 12 \
        -k 21,33,55,77 \
        -o strategyA_strict 2>&1 | tee strategyA_strict.log
    
    if [[ $? -eq 0 ]] && [[ -f "strategyA_strict/contigs.fasta" ]]; then
        echo "✅ 策略A完成"
    else
        echo "❌ 策略A失败，查看日志: strategyA_strict.log"
    fi
else
    echo "❌ 策略A跳过: 输入文件不存在"
fi

# 策略B: 使用覆盖度过滤
echo "🔧 策略B: SPAdes + 覆盖度过滤..."
mkdir -p strategyB_coverage

if [[ -f "$cleaned_read1" ]] && [[ -f "$cleaned_read2" ]]; then
    spades.py \
        --isolate \
        --pe1-1 "$cleaned_read1" \
        --pe1-2 "$cleaned_read2" \
        --threads 8 \
        --memory 12 \
        --cov-cutoff 10 \
        -k 21,33,55 \
        -o strategyB_coverage 2>&1 | tee strategyB_coverage.log
    
    if [[ $? -eq 0 ]] && [[ -f "strategyB_coverage/contigs.fasta" ]]; then
        echo "✅ 策略B完成"
    else
        echo "❌ 策略B失败，查看日志: strategyB_coverage.log"
    fi
else
    echo "❌ 策略B跳过: 输入文件不存在"
fi

# 策略C: MEGAHIT (适合高覆盖度数据)
if command -v megahit &>/dev/null; then
    echo "🔧 策略C: MEGAHIT组装..."
    
    if [[ -f "$cleaned_read1" ]] && [[ -f "$cleaned_read2" ]]; then
        megahit \
            -1 "$cleaned_read1" \
            -2 "$cleaned_read2" \
            -o strategyC_megahit \
            -t 8 \
            --min-contig-len 500 \
            --k-min 21 \
            --k-max 77 \
            --k-step 10 \
            --force 2>&1 | tee strategyC_megahit.log
        
        # 检查MEGAHIT是否成功完成
        if [[ $? -eq 0 ]] && [[ -f "strategyC_megahit/final.contigs.fa" ]]; then
            echo "✅ MEGAHIT组装完成"
        else
            echo "❌ MEGAHIT组装失败，查看日志: strategyC_megahit.log"
        fi
    else
        echo "❌ 策略C跳过: 输入文件不存在"
    fi
else
    echo "⚠️  MEGAHIT未安装，跳过策略C"
fi

echo ""
echo "=== 步骤4: 结果对比分析 ==="

echo "📊 各策略组装结果对比:"
printf "%-18s | %-9s | %-12s | %-13s | %s\n" "策略" "Contigs数" "基因组大小" "最长Contig" "N50"
printf "%-18s | %-9s | %-12s | %-13s | %s\n" "------------------" "---------" "------------" "-------------" "----"

for strategy in "strategyA_strict" "strategyB_coverage" "strategyC_megahit"; do
    if [[ "$strategy" == "strategyC_megahit" ]]; then
        contigs_file="$strategy/final.contigs.fa"
    else
        contigs_file="$strategy/contigs.fasta"
    fi
    
    if [[ -f "$contigs_file" ]]; then
        contigs_count=$(grep "^>" "$contigs_file" | wc -l)
        genome_size=$(grep -v "^>" "$contigs_file" | tr -d '\n' | wc -c)
        
        # 获取最长contig长度
        if [[ "$strategy" == "strategyC_megahit" ]]; then
            longest_contig=$(grep "^>" "$contigs_file" | grep -o "len=[0-9]*" | cut -d'=' -f2 | sort -nr | head -1)
        else
            longest_contig=$(grep "^>" "$contigs_file" | grep -o "length_[0-9]*" | cut -d'_' -f2 | sort -nr | head -1 2>/dev/null || echo "N/A")
        fi
        
        # 简单N50计算
        if [[ "$strategy" == "strategyC_megahit" ]]; then
            grep "^>" "$contigs_file" | grep -o "len=[0-9]*" | cut -d'=' -f2 | sort -nr > lengths.tmp
        else
            grep "^>" "$contigs_file" | grep -o "length_[0-9]*" | cut -d'_' -f2 | sort -nr > lengths.tmp 2>/dev/null
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
        else
            n50="N/A"
        fi
        
        genome_mb=$(echo "scale=2; $genome_size/1000000" | bc 2>/dev/null || echo "N/A")
        
        printf "%-18s | %-9s | %-12s | %-13s | %s\n" \
            "$strategy" "$contigs_count" \
            "${genome_mb}Mb" "$longest_contig" "$n50"
        
        rm -f lengths.tmp
    else
        printf "%-18s | %-9s | %-12s | %-13s | %s\n" \
            "$strategy" "FAILED" "-" "-" "-"
        
        # 显示错误信息
        if [[ -f "${strategy}.log" ]]; then
            echo "    错误日志摘要:"
            tail -3 "${strategy}.log" | sed 's/^/    /'
        fi
    fi
done

echo ""
echo "=== 步骤5: 推荐方案 ==="

# 找到最好的结果
best_strategy=""
min_contigs=999999
best_file=""
best_genome_size=0

for strategy in "strategyA_strict" "strategyB_coverage" "strategyC_megahit"; do
    if [[ "$strategy" == "strategyC_megahit" ]]; then
        contigs_file="$strategy/final.contigs.fa"
    else
        contigs_file="$strategy/contigs.fasta"
    fi
    
    if [[ -f "$contigs_file" ]]; then
        contigs_count=$(grep "^>" "$contigs_file" | wc -l)
        genome_size=$(grep -v "^>" "$contigs_file" | tr -d '\n' | wc -c)
        
        # 选择contigs数量少且基因组大小合理的策略
        if [[ $contigs_count -lt $min_contigs ]] && [[ $genome_size -gt 1000000 ]]; then
            min_contigs=$contigs_count
            best_strategy=$strategy
            best_file=$contigs_file
            best_genome_size=$genome_size
        fi
    fi
done

if [[ -n "$best_strategy" ]]; then
    echo "🏆 推荐策略: $best_strategy"
    echo "📁 最佳结果文件: $best_file"
    echo "📊 基因组大小: $(echo "scale=2; $best_genome_size/1000000" | bc)Mb"
    echo "📊 Contigs数量: $min_contigs"
    
    # 复制最佳结果到主目录
    cp "$best_file" "BEST_assembly_contigs.fasta"
    echo "✅ 最佳结果已复制为 BEST_assembly_contigs.fasta"
    
    # 生成简单的统计报告
    echo ""
    echo "📋 详细统计报告:"
    echo "总序列长度: $(grep -v "^>" BEST_assembly_contigs.fasta | tr -d '\n' | wc -c) bp"
    echo "最大contig: $(grep "^>" BEST_assembly_contigs.fasta | head -1)"
    
else
    echo "⚠️  没有找到满意的组装结果"
    echo "🔍 建议检查输入数据质量和组装参数"
fi

echo ""
echo "🎯 后续建议:"
echo "1. 使用QUAST进行详细质量评估: quast.py BEST_assembly_contigs.fasta"
echo "2. 用CheckM检查基因组完整性"
echo "3. 使用Kraken2检测潜在污染"
echo "4. 如果结果不满意，考虑调整组装参数"

echo ""
echo "📁 所有结果文件位置: $analysis_dir"
echo "🏁 修复版高级分析完成！"
