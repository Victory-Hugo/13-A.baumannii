#!/bin/bash

echo "🧬 ============================================================="
echo "    鲍曼不动杆菌 ERR197551 EToKi 组装流程完成总结"
echo "==============================================================="
echo ""

echo "✅ 完成的步骤:"
echo "   1. ✅ 激活etoki虚拟环境"
echo "   2. ✅ 数据预处理 (EToKi prepare)"
echo "   3. ✅ 基因组组装 (EToKi assemble + SPAdes)"
echo "   4. ✅ 序列比对和polish处理"
echo "   5. ✅ 组装质量评估"
echo ""

echo "📊 组装结果概览:"
echo "   • 基因组大小: 4.81 Mb"
echo "   • Contigs数量: 2,568"
echo "   • 最长contig: 268,805 bp"
echo "   • N50: 63,790 bp"
echo "   • 大于10kb的contigs: 63个"
echo ""

echo "📁 主要输出文件:"
echo "   • 最终组装序列: ERR197551_assembly/etoki.mapping.reference.fasta"
echo "   • SPAdes原始contigs: ERR197551_assembly/spades/contigs.fasta"
echo "   • SPAdes scaffolds: ERR197551_assembly/spades/scaffolds.fasta"
echo "   • 比对BAM文件: ERR197551_assembly/etoki.mapping.merged.bam"
echo "   • 清理后的测序数据: ERR197551_cleaned_L1_R*.fastq.gz"
echo ""

echo "🎯 质量评估:"
echo "   ✅ N50良好 (63,790 bp)"
echo "   ⚠️  基因组稍大于预期 (可能包含重复序列)"
echo "   ❌ Contigs较多 (2,568个，较为碎片化)"
echo ""

echo "🔬 后续分析建议:"
echo "   1. 基因组质量评估:"
echo "      conda install quast -c bioconda"
echo "      quast.py ERR197551_assembly/etoki.mapping.reference.fasta -o quast_results"
echo ""
echo "   2. 基因组完整性检查:"
echo "      conda install checkm-genome -c bioconda"
echo "      checkm lineage_wf ERR197551_assembly checkm_results"
echo ""
echo "   3. 污染检测:"
echo "      conda install kraken2 -c bioconda"
echo "      kraken2 --db minikraken2 ERR197551_assembly/etoki.mapping.reference.fasta"
echo ""
echo "   4. 基因注释:"
echo "      conda install prokka -c bioconda"
echo "      prokka ERR197551_assembly/etoki.mapping.reference.fasta --outdir annotation --genus Acinetobacter --species baumannii"
echo ""
echo "   5. MLST分型 (需要下载对应数据库):"
echo "      EToKi.py MLSType -i ERR197551_assembly/etoki.mapping.reference.fasta -r mlst_db.fasta -k ERR197551"
echo ""

echo "🏆 恭喜！您已成功完成鲍曼不动杆菌ERR197551的基因组组装！"
echo ""

# 显示文件大小和位置
echo "📍 文件位置和大小:"
cd /mnt/c/Users/Administrator/Desktop/etoki_assembly
ls -lh ERR197551_assembly/etoki.mapping.reference.fasta
ls -lh ERR197551_assembly/spades/contigs.fasta
ls -lh ERR197551_assembly/spades/scaffolds.fasta
echo ""

echo "💡 温馨提示:"
echo "   • 最终组装文件可用于下游分析"
echo "   • 建议进行基因组注释以识别基因功能"
echo "   • 可以与参考基因组比较分析变异"
echo "   • 可进行抗性基因和毒力因子预测"

质量评估: 使用QUAST进行详细评估
完整性检查: 使用CheckM评估基因组完整性
污染检测: 使用Kraken2检测潜在污染
基因注释: 使用Prokka进行基因功能注释
分型分析: 进行MLST分型和抗性基因预测