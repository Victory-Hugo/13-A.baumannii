#!/bin/bash
# 过滤VCF文件，去除低质量变异，用于系统发育
bcftools filter -e 'QUAL<20 || INFO/DP<3 || MQ<30' \
    -Oz -o \
    /mnt/d/6-HPgnomAD-Origin-data/5-NCBI/2-Ancient-DNA/VCF/ancient_top3.filtered.vcf.gz \
    /mnt/d/6-HPgnomAD-Origin-data/5-NCBI/2-Ancient-DNA/VCF/ancient_top3.vcf.gz

# 保留SNP，转为fasta
bcftools view -v snps \
    -Oz -o \
    /mnt/d/6-HPgnomAD-Origin-data/5-NCBI/2-Ancient-DNA/VCF/ancient_top3.filtered.snps.vcf.gz \
    /mnt/d/6-HPgnomAD-Origin-data/5-NCBI/2-Ancient-DNA/VCF/ancient_top3.filtered.vcf.gz

bcftools index /mnt/d/6-HPgnomAD-Origin-data/5-NCBI/2-Ancient-DNA/VCF/ancient_top3.filtered.snps.vcf.gz
# 参考序列使用/mnt/d/6-HPgnomAD-Origin-data/6-Annotation/Reference/NC_000915.fasta
bcftools consensus -f /mnt/d/6-HPgnomAD-Origin-data/6-Annotation/Reference/NC_000915.fasta \
    /mnt/d/6-HPgnomAD-Origin-data/5-NCBI/2-Ancient-DNA/VCF/ancient_top3.filtered.snps.vcf.gz \
    > /mnt/d/6-HPgnomAD-Origin-data/5-NCBI/2-Ancient-DNA/VCF/ancient_top3.filtered.snps.fasta

seqmagick2 convert --rename \
    /mnt/d/6-HPgnomAD-Origin-data/5-NCBI/2-Ancient-DNA/VCF/name.txt \
    /mnt/d/6-HPgnomAD-Origin-data/5-NCBI/2-Ancient-DNA/VCF/ancient_top3.filtered.snps.fasta \
    /mnt/d/6-HPgnomAD-Origin-data/5-NCBI/2-Ancient-DNA/VCF/HP_aDNA_WGS.fasta