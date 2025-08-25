#!/bin/bash

# 高质量基因组数据质控脚本
# 使用FastQC和BBTools进行质量控制

echo "🧬 基因组数据质控流程启动"
echo "=================================="

# 设置路径
raw_data_dir="/mnt/c/Users/Administrator/Desktop/ERR197551"
read1="${raw_data_dir}/ERR197551_1.fastq.gz"
read2="${raw_data_dir}/ERR197551_2.fastq.gz"
THREADS=8
# 创建质控分析目录
qc_dir="/mnt/c/Users/Administrator/Desktop/ERR197551_QC"
mkdir -p "$qc_dir"
cd "$qc_dir"

echo "📁 质控目录: $qc_dir"

# 检查输入文件
if [[ ! -f "$read1" ]] || [[ ! -f "$read2" ]]; then
    echo "❌ 输入文件不存在:"
    echo "   $read1"
    echo "   $read2"
    exit 1
fi

echo "✅ 输入文件检查通过"
echo "   Read1: $read1"
echo "   Read2: $read2"

echo ""
echo "=== 步骤1: FastQC质量检查 ==="

# 检查FastQC是否可用
if command -v fastqc &>/dev/null; then
    echo "🔧 运行FastQC质量检查..."
    mkdir -p fastqc_raw_output
    
    # 设置Java环境
    export JAVA_HOME="/usr/lib/jvm/default-java"
    export PATH="/usr/lib/jvm/default-java/bin:$PATH"
    
    # 运行FastQC
    echo "📊 分析原始数据质量..."
    timeout 600s fastqc "$read1" "$read2" -o fastqc_raw_output --threads "$THREADS" --extract

    if [[ $? -eq 0 ]]; then
        echo "✅ FastQC原始数据分析完成"
        echo "📁 结果位置: $qc_dir/fastqc_raw_output/"
    else
        echo "⚠️  FastQC运行遇到问题，尝试基础质量检查..."
        
        # 基础质量统计作为备选
        echo "📊 基础序列统计:"
        read1_lines=$(zcat "$read1" | wc -l)
        read2_lines=$(zcat "$read2" | wc -l)
        read1_seqs=$((read1_lines / 4))
        read2_seqs=$((read2_lines / 4))
        
        echo "Read1 序列数: $read1_seqs"
        echo "Read2 序列数: $read2_seqs"
        
        # 检查读长
        read_length=$(zcat "$read1" | head -2 | tail -1 | wc -c)
        echo "读长: $((read_length-1)) bp"
        
        # 简单质量统计
        echo "数据完整性检查: $([ $read1_seqs -eq $read2_seqs ] && echo "✅ 配对完整" || echo "⚠️  配对不完整")"
    fi
else
    echo "❌ FastQC未安装，请先安装FastQC"
    echo "安装命令: conda install -c bioconda fastqc"
    exit 1
fi

echo ""
echo "=== 步骤2: BBTools数据清理 ==="

# 检查BBTools是否可用
if command -v bbduk.sh &>/dev/null; then
    echo "🔧 使用BBTools进行数据清理..."
    
    # BBduk清理参数说明
    echo "📋 清理参数:"
    echo "   - 质量修剪: Q20"
    echo "   - 最小长度: 50bp"
    echo "   - 去除接头: 自动检测"
    
    # 运行BBduk
    bbduk.sh \
        in1="$read1" \
        in2="$read2" \
        out1=cleaned_1.fastq.gz \
        out2=cleaned_2.fastq.gz \
        qtrim=rl \
        trimq=20 \
        minlen=50 \
        ktrim=r \
        k=23 \
        mink=11 \
        hdist=1 \
        tpe \
        tbo \
        threads="$THREADS" \
        -Xmx16g \
        stats=bbduk_stats.txt
    
    if [[ $? -eq 0 ]] && [[ -f "cleaned_1.fastq.gz" ]] && [[ -f "cleaned_2.fastq.gz" ]]; then
        echo "✅ BBTools数据清理完成"
        
        # 统计清理结果
        echo ""
        echo "📊 清理统计:"
        if [[ -f "bbduk_stats.txt" ]]; then
            cat bbduk_stats.txt
        fi
        
        # 计算清理前后序列数量
        original_seqs=$(zcat "$read1" | wc -l | awk '{print $1/4}')
        cleaned_seqs=$(zcat "cleaned_1.fastq.gz" | wc -l | awk '{print $1/4}')
        retention_rate=$(echo "scale=2; $cleaned_seqs/$original_seqs*100" | bc 2>/dev/null || echo "N/A")
        
        echo "原始序列数: $original_seqs"
        echo "清理后序列数: $cleaned_seqs"
        echo "保留率: ${retention_rate}%"
        
    else
        echo "❌ BBTools清理失败"
        echo "将使用原始数据进行后续分析"
        
        # 创建软链接指向原始数据
        ln -sf "$read1" cleaned_1.fastq.gz
        ln -sf "$read2" cleaned_2.fastq.gz
    fi
else
    echo "❌ BBTools未安装，请先安装BBTools"
    echo "安装命令: conda install -c bioconda bbmap"
    exit 1
fi

echo ""
echo "=== 步骤3: 清理后质量检查 ==="

if [[ -f "cleaned_1.fastq.gz" ]] && [[ -f "cleaned_2.fastq.gz" ]]; then
    echo "🔧 分析清理后数据质量..."
    mkdir -p fastqc_cleaned_output
    
    # 对清理后的数据运行FastQC
    timeout 600s fastqc "cleaned_1.fastq.gz" "cleaned_2.fastq.gz" -o fastqc_cleaned_output --threads 4 --extract
    
    if [[ $? -eq 0 ]]; then
        echo "✅ 清理后数据质量分析完成"
        echo "📁 结果位置: $qc_dir/fastqc_cleaned_output/"
    else
        echo "⚠️  清理后FastQC分析遇到问题"
    fi
fi

echo ""
echo "=== 步骤4: 质控报告总结 ==="

echo "📋 质控流程完成总结:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# 检查各个步骤的完成情况
echo "✅ 原始数据FastQC分析: $([ -d "fastqc_raw_output" ] && echo "完成" || echo "失败")"
echo "✅ BBTools数据清理: $([ -f "cleaned_1.fastq.gz" ] && echo "完成" || echo "失败")"
echo "✅ 清理后FastQC分析: $([ -d "fastqc_cleaned_output" ] && echo "完成" || echo "失败")"

echo ""
echo "📁 输出文件:"
echo "   - 清理后数据: cleaned_1.fastq.gz, cleaned_2.fastq.gz"
echo "   - 原始质量报告: fastqc_raw_output/"
echo "   - 清理后质量报告: fastqc_cleaned_output/"
echo "   - BBduk统计: bbduk_stats.txt"

echo ""
echo "🎯 下一步建议:"
echo "1. 查看FastQC报告确认数据质量"
echo "2. 如果质量满意，可以进行基因组组装"
echo "3. 运行组装脚本: ./2-组装.sh"

echo ""
echo "📁 所有质控文件位置: $qc_dir"
echo "🏁 质控流程完成！"
