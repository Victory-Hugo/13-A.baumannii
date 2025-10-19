#!/bin/bash

indir="/data_raid/7_luolintao/1_Baoman/1-Assemble/NCBI_Sequence_1/fasta"



# 遍历目录下的 fasta/fa/fna 文件
find "$indir" -maxdepth 1 -type f \( -name "*.fasta" -o -name "*.fa" -o -name "*.fna" \) -print0 |
while IFS= read -r -d '' f; do
  ext="${f##*.}"
  base=$(basename "$f" ."$ext")
  echo "🔄 正在处理 $f ..."
  # 用 awk 重写 contig header
  awk -v base="$base" 'BEGIN{c=0} 
    /^>/ {c++; print ">" base "_" c; next} 
    {print}' "$f" > "$f.tmp" && mv "$f.tmp" "$f"
done

echo "✅ 所有 fasta 文件重命名完成"
