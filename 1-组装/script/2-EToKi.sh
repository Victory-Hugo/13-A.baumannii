#!/bin/bash

# 仅使用 EToKi 的基因组组装脚本（手动指定 FASTQ 文件路径）

echo "🧬 基因组组装流程启动（EToKi）"
echo "=================================="

# ===== 手动输入 FASTQ 文件路径 =====
# 请手动修改以下两行，填写你的 FASTQ 文件绝对路径
BASENAME="ERR1946991"
read1="/data_raid/7_luolintao/1_Baoman/2-Sequence/data/FASTQ/${BASENAME}/${BASENAME}.sra_1.fastq.gz"
read2="/data_raid/7_luolintao/1_Baoman/2-Sequence/data/FASTQ/${BASENAME}/${BASENAME}.sra_2.fastq.gz"
assembly_dir="/data_raid/7_luolintao/1_Baoman/1-Assemble/${BASENAME}_Assembly"
FINAL_FASTA="${assembly_dir}/${BASENAME}.fasta"
# 检查输入文件是否存在
if [[ ! -f "$read1" || ! -f "$read2" ]]; then
    echo "❌ 输入文件不存在，请检查路径:"
    echo "   Read1: $read1"
    echo "   Read2: $read2"
    exit 1
fi

echo "✅ 输入文件检查通过"
echo "   Read1: $read1"
echo "   Read2: $read2"

# ===== 组装目录 =====

mkdir -p "$assembly_dir"
cd "$assembly_dir" || { echo "❌ 无法进入目录: $assembly_dir"; exit 1; }
echo "📁 组装目录: $assembly_dir"

# ===== 仅保留 EToKi 流程 =====
echo ""
echo "=== 执行：EToKi 综合流程 ==="

# 检查 EToKi
if ! command -v EToKi.py &>/dev/null; then
    echo "❌ EToKi 未安装，请先安装"
    echo "安装命令: conda install -c bioconda etoki"
    exit 1
fi

mkdir -p etoki_assembly
cd etoki_assembly || { echo "❌ 无法进入目录: etoki_assembly"; exit 1; }

# 可配置前缀（用于 EToKi 输出文件命名）
prefix=${BASENAME}

# 步骤1：EToKi 数据预处理
echo "📊 EToKi 数据预处理..."
time EToKi.py prepare \
    --pe "$read1","$read2" \
    --prefix "${prefix}_cleaned" 2>&1 | tee etoki_prepare.log

if [[ ${PIPESTATUS[0]} -ne 0 ]]; then
    echo "❌ EToKi 数据预处理失败，查看日志: etoki_prepare.log"
    exit 1
fi
echo "✅ 预处理完成"

# 预处理后 EToKi 规范的 R1/R2 名称
R1="${prefix}_cleaned_L1_R1.fastq.gz"
R2="${prefix}_cleaned_L1_R2.fastq.gz"
if [[ ! -f "$R1" || ! -f "$R2" ]]; then
    echo "❌ 未找到预处理输出: $R1 / $R2"
    echo "请检查 etoki_prepare.log"
    exit 1
fi

# 步骤2：EToKi 组装
echo "🔧 EToKi 基因组组装..."
time EToKi.py assemble \
    --pe "$R1","$R2" \
    --prefix "${prefix}_assembly" \
    --assembler spades \
    --kraken \
    --accurate_depth 2>&1 | tee etoki_assembly.log

if [[ ${PIPESTATUS[0]} -ne 0 ]]; then
    echo "❌ EToKi 组装失败，查看日志: etoki_assembly.log"
    exit 1
fi


echo "✅ 组装完成"

# 检查并移动组装结果文件
if [[ -f "${prefix}_assembly/etoki.mapping.reference.fasta" ]]; then
    mv "${prefix}_assembly/etoki.mapping.reference.fasta" "$FINAL_FASTA"
    echo "📄 组装结果保存至: $FINAL_FASTA"
else
    echo "⚠️ 未找到预期的组装结果文件"
fi

# 删除不必要的中间文件
rm -rf "${assembly_dir}/etoki_assembly/${prefix}_assembly/spades/"
rm -f "${assembly_dir}/etoki_assembly/${prefix}_assembly/"*.fastq.gz
rm -f "${assembly_dir}/etoki_assembly/${prefix}_assembly/"*.bam "${assembly_dir}/etoki_assembly/${prefix}_assembly/"*.bai
echo "🗑️ 删除中间文件完成"
# ===== 确定结果文件 =====
result_file=""
scaffolds_file=""

if [[ -f "${prefix}_assembly/etoki.mapping.reference.fasta" ]]; then
    result_file="../etoki_assembly/${prefix}_assembly/etoki.mapping.reference.fasta"
elif [[ -f "${prefix}_assembly/spades/contigs.fasta" ]]; then
    result_file="../etoki_assembly/${prefix}_assembly/spades/contigs.fasta"
fi

if [[ -f "${prefix}_assembly/spades/scaffolds.fasta" ]]; then
    scaffolds_file="../etoki_assembly/${prefix}_assembly/spades/scaffolds.fasta"
fi

cd "$assembly_dir" || exit 1


# ===== 总结 =====
echo ""
echo "=== 组装完成总结（EToKi） ==="
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📁 组装目录: $assembly_dir"
echo "📄 主要输出文件:"
echo "   - final_assembly_contigs.fasta"
if [[ -f "final_assembly_scaffolds.fasta" ]]; then
    echo "   - final_assembly_scaffolds.fasta"
fi
echo "   - etoki_assembly/etoki.mapping.reference.fasta"
echo "   - etoki_assembly/etoki_prepare.log"
echo "   - etoki_assembly/etoki_assembly.log"

echo ""
echo "🎯 后续建议:"
echo "1. 质量评估: quast.py final_assembly_contigs.fasta"
echo "2. 完整性检查: checkm lineage_wf -t 8 -x fasta . checkm_output"
echo "3. 污染检测: kraken2 --db <kraken_db> final_assembly_contigs.fasta"
echo "4. 基因注释: prokka --outdir annotation --prefix sample final_assembly_contigs.fasta"

echo ""
echo "🏁 基因组组装流程完成（EToKi-only）！"
