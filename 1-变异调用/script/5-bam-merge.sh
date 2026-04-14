#!/usr/bin/env bash
set -euo pipefail

hp_ref=/mnt/d/6-HPgnomAD-Origin-data/6-Annotation/Reference/NC_000915.fasta
BAM_DIR="/mnt/d/6-HPgnomAD-Origin-data/5-NCBI/2-Ancient-DNA/BAM/"
QUALITY_DIR="/mnt/d/6-HPgnomAD-Origin-data/5-NCBI/2-Ancient-DNA/quality/"
VCF_DIR="/mnt/d/6-HPgnomAD-Origin-data/5-NCBI/2-Ancient-DNA/VCF/"

samtools merge -f ${BAM_DIR}ancient_top3.bam \
  ${BAM_DIR}ERR1094798.sorted.bam \
  ${BAM_DIR}ERR1094802.sorted.bam \
  ${BAM_DIR}ERR1094809.sorted.bam

samtools sort -o ${BAM_DIR}ancient_top3.sorted.bam \
    ${BAM_DIR}ancient_top3.bam

samtools index ${BAM_DIR}ancient_top3.sorted.bam

samtools coverage -m ${BAM_DIR}ancient_top3.sorted.bam >\
    ${QUALITY_DIR}/coverage/ancient_top3.coverage.txt

mapDamage -i ${BAM_DIR}ancient_top3.sorted.bam \
    -r $hp_ref \
    --no-stats > ${QUALITY_DIR}/damage/ancient_top3_mapDamage.txt

bcftools mpileup -f $hp_ref -a DP,AD -q 30 -Q 30 ${BAM_DIR}/ancient_top3.sorted.bam \
| bcftools call -mv -Oz -o ${VCF_DIR}/ancient_top3.vcf.gz

bcftools index ${VCF_DIR}/ancient_top3.vcf.gz

bcftools consensus -f $hp_ref ${VCF_DIR}/ancient_top3.vcf.gz \
> ${VCF_DIR}/ancient_top3.consensus.fasta

