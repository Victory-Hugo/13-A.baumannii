#!/bin/bash
DB_PATH="/home/luolintao/miniconda3/envs/etoki/share/etoki-1.2.3/externals/minikraken2/minikraken2_v2_8GB_201904_UPDATE"

kraken2 \
  --db "${DB_PATH}" \
  --paired /data_raid/7_luolintao/1_Baoman/2-Sequence/FASTQ/ERR1946991_1.fastq.gz \
    /data_raid/7_luolintao/1_Baoman/2-Sequence/FASTQ/ERR1946991_2.fastq.gz \
  --threads 8 \
  --report /data_raid/7_luolintao/1_Baoman/3-Kraken/ERR1946991_kraken_report.txt \
  --output /data_raid/7_luolintao/1_Baoman/3-Kraken/ERR1946991_kraken_output.txt
