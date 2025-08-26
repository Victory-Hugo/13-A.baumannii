#!/bin/bash

# 数据目录
DATADIR="/data_raid/7_luolintao/1_Baoman/2-Sequence/data/FASTQ"

# 遍历所有 fastq 文件
for f in ${DATADIR}/*.fastq.gz; do
    # 提取文件名（不含路径）
    fname=$(basename "$f")

    # 提取基名（去掉.sra_1.fastq 或 .sra_2.fastq）
    bname=$(echo "$fname" | sed -E 's/\.sra_[12]\.fastq\.gz//')

    # 创建对应的目录
    mkdir -p "${DATADIR}/${bname}"

    # 移动文件
    mv "$f" "${DATADIR}/${bname}/"
done
