#!/bin/bash
# 用法: bash rename_contigs.sh /mnt/d/1-鲍曼菌/组装完成/

indir="/mnt/d/1-鲍曼菌/组装完成"



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
