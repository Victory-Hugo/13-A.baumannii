#!/bin/bash
#?=================脚本说明=================#
#? 该脚本用于将古DNA的FASTQ文件比对到参考基因组，生成BAM文件
#*===========软件配置区域============*#
ADNA_FASTQ_SAI="/mnt/f/OneDrive/文档（科研）/脚本/Download/13-A.baumannii/1-变异调用/script/1-aDNA-FASTQ→SAI.sh"
FASTQ_SAI_LIST_PY="/mnt/f/OneDrive/文档（科研）/脚本/Download/13-A.baumannii/1-变异调用/script/0-FASTQ→SAI_FQ_LIST.py"
MERGE_QUALITY_PY="/mnt/f/OneDrive/文档（科研）/脚本/Download/13-A.baumannii/1-变异调用/script/merge.py"
#*===========文件配置区域============*#
REFERENCE_FASTA="/mnt/d/6-HPgnomAD-Origin-data/6-Annotation/Reference/NC_000915.fasta" #! 需要建立索引
FASTQ_TXT="/mnt/f/OneDrive/文档（科研）/脚本/Download/13-A.baumannii/1-变异调用/conf/FASTQ_list.txt" #! 每行一个fastq文件的路径
SAI_OUT_DIR="/mnt/d/6-HPgnomAD-Origin-data/5-NCBI/2-Ancient-DNA/SAI"
SAI_LOG="/mnt/d/6-HPgnomAD-Origin-data/5-NCBI/2-Ancient-DNA/logs/FASTQ_to_SAI.log"
SAI_FQ_LIST="/mnt/f/OneDrive/文档（科研）/脚本/Download/13-A.baumannii/1-变异调用/conf/SAI_list.txt" #! 每行4列：sai1 sai2 fq1 fq2
#*===========文件配置区域============*#

#*===========第一步骤============*#
# bash "${ADNA_FASTQ_SAI}" \
#   -r ${REFERENCE_FASTA} \
#   -i ${FASTQ_TXT} \
#   -o ${SAI_OUT_DIR} \
#   -t 6 \
#   -l ${SAI_LOG}

#*===========生成SAI_FQ_LIST============*#
# python3 "${FASTQ_SAI_LIST_PY}" \
#   -i ${FASTQ_TXT} \
#   -s ${SAI_OUT_DIR} \
#   -o ${SAI_FQ_LIST}

#*===========第二步骤============*#
SAI_FQ="/mnt/f/OneDrive/文档（科研）/脚本/Download/13-A.baumannii/1-变异调用/script/2-SAI→BAM.sh"
ADNA_QUALITY="/mnt/f/OneDrive/文档（科研）/脚本/Download/13-A.baumannii/1-变异调用/script/3-quality-exam.sh"
ADNA_DAMAGE="/mnt/f/OneDrive/文档（科研）/脚本/Download/13-A.baumannii/1-变异调用/script/4-damage-exam.sh"
BAM_OUT_DIR="/mnt/d/6-HPgnomAD-Origin-data/5-NCBI/2-Ancient-DNA/BAM"
BAM_LOG="/mnt/d/6-HPgnomAD-Origin-data/5-NCBI/2-Ancient-DNA/logs/SAI_to_BAM.log"
QUALITY_OUT_DIR="/mnt/d/6-HPgnomAD-Origin-data/5-NCBI/2-Ancient-DNA/quality"
QUALITY_LOG="/mnt/d/6-HPgnomAD-Origin-data/5-NCBI/2-Ancient-DNA/logs/quality_exam.log"
DAMAGE_LOG="/mnt/d/6-HPgnomAD-Origin-data/5-NCBI/2-Ancient-DNA/logs/damage_exam.log"
QUALITY_MERGE_PREFIX="quality_merged"

# bash "${SAI_FQ}" \
#   -t 6 \
#   -r ${REFERENCE_FASTA} \
#   -i ${SAI_FQ_LIST} \
#   -o ${BAM_OUT_DIR} \
#   -l ${BAM_LOG}

# #*===========第三步骤：质量评估============*#
# bash "${ADNA_QUALITY}" \
#   -i ${SAI_FQ_LIST} \
#   -b ${BAM_OUT_DIR} \
#   -o ${QUALITY_OUT_DIR} \
#   -t 6 \
#   -l ${QUALITY_LOG}

# #*===========第四步骤：损伤评估============*#
# bash "${ADNA_DAMAGE}" \
#   -r ${REFERENCE_FASTA} \
#   -i ${SAI_FQ_LIST} \
#   -b ${BAM_OUT_DIR} \
#   -o ${QUALITY_OUT_DIR} \
#   -t 6 \
#   -l ${DAMAGE_LOG}

#*===========第五步骤：汇总结果============*#
python3 "${MERGE_QUALITY_PY}" \
  -q ${QUALITY_OUT_DIR} \
  -o ${QUALITY_OUT_DIR} \
  -m two \
  -p ${QUALITY_MERGE_PREFIX}
