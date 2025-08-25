EToKi.py \
    prepare --pe ../ERR197551/ERR197551_1.fastq.gz,../ERR197551/ERR197551_2.fastq.gz \
    --prefix ERR197551_cleaned

EToKi.py assemble \
    --pe ERR197551_cleaned_L1_R1.fastq.gz,ERR197551_cleaned_L1_R2.fastq.gz \
    --prefix ERR197551_assembly \
    --assembler spades

EToKi.py assemble \
  --pe /mnt/c/Users/Administrator/Desktop/etoki_assembly/ERR197551_cleaned_L1_R1.fastq.gz,/mnt/c/Users/Administrator/Desktop/etoki_assembly/ERR197551_cleaned_L1_R2.fastq.gz \
  --prefix ERR197551_assembly \
  --assembler spades \
  --kraken \
  --accurate_depth

重要输出文件：
ERR197551_assembly/etoki.mapping.reference.fasta - 最终组装序列
ERR197551_assembly/spades/contigs.fasta - SPAdes原始contigs
ERR197551_assembly/spades/scaffolds.fasta - SPAdes scaffolds
ERR197551_assembly/etoki.mapping.merged.bam - 比对文件
🎯 下一步建议：
质量评估: 使用QUAST进行详细评估
完整性检查: 使用CheckM评估基因组完整性
污染检测: 使用Kraken2检测潜在污染
基因注释: 使用Prokka进行基因功能注释
分型分析: 进行MLST分型和抗性基因预测