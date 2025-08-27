#!/bin/bash

# Kaptive分析脚本：预测A. baumannii的OCL和cps类型
# 用途：使用Kaptive v2.0.3预测鲍曼不动杆菌的荚膜多糖类型
# 变更点：
# 1) 自动识别 /mnt/d/1-鲍曼菌/组装完成/ 下所有 .fasta
# 2) 优先使用 GNU parallel；当 PARALLEL_JOBS==1 或未装 parallel 时回退 for 循环
# 3) 功能其它保持不变

# ================== 可配置区 ==================
INPUT_DIR="/mnt/d/1-鲍曼菌/组装完成" #? 文件夹下全是组装好的fasta文件
OUTPUT_DIR="/mnt/d/1-鲍曼菌/荚膜多糖"

# 并发任务数
PARALLEL_JOBS="2"
# ============================================

# 创建输出目录
mkdir -p "${OUTPUT_DIR}"
mkdir -p "${OUTPUT_DIR}/OCL_results"
mkdir -p "${OUTPUT_DIR}/K_locus_results"

echo "开始Kaptive分析..."
echo "分析时间：$(date)"
echo "输入目录：${INPUT_DIR}"
echo "输出目录：${OUTPUT_DIR}"
echo "并发任务数(PARALLEL_JOBS)：${PARALLEL_JOBS}"
echo "================================"

# 收集所有 .fasta 文件
mapfile -d '' -t FASTAS < <(find "${INPUT_DIR}" -maxdepth 1 -type f -name "*.fasta" -print0)

if [ "${#FASTAS[@]}" -eq 0 ]; then
  echo "未在 ${INPUT_DIR} 中发现 .fasta 文件，脚本结束。"
  exit 0
fi

run_one_sample() {
  local fasta="$1"
  local sample
  sample="$(basename "$fasta")"
  sample="${sample%.*}"

  echo "正在分析样本：${sample}"

  # OCL
  echo "  - 分析OCL类型..."
  kaptive assembly ab_o "${fasta}" \
    -o "${OUTPUT_DIR}/OCL_results/${sample}_OCL_results.tsv" \
    --plot "${OUTPUT_DIR}/OCL_results/" \
    --fasta "${OUTPUT_DIR}/OCL_results/" \
    --json "${OUTPUT_DIR}/OCL_results/${sample}_OCL_results.json" \
    --threads 0 \
    --verbose

  # K locus
  echo "  - 分析K locus类型..."
  kaptive assembly ab_k "${fasta}" \
    -o "${OUTPUT_DIR}/K_locus_results/${sample}_K_locus_results.tsv" \
    --plot "${OUTPUT_DIR}/K_locus_results/" \
    --fasta "${OUTPUT_DIR}/K_locus_results/" \
    --json "${OUTPUT_DIR}/K_locus_results/${sample}_K_locus_results.json" \
    --threads 0 \
    --verbose

  echo "  样本 ${sample} 分析完成"
  echo "  --------------------------------"
}

# 决定并发方式：parallel (jobs>1 且已安装) 否则 for
if command -v parallel >/dev/null 2>&1 && [ "${PARALLEL_JOBS}" -gt 1 ]; then
  echo "使用 GNU parallel 运行（jobs=${PARALLEL_JOBS}）"
  export -f run_one_sample
  export OUTPUT_DIR
  printf '%s\0' "${FASTAS[@]}" | parallel -0 --jobs "${PARALLEL_JOBS}" --will-cite 'run_one_sample {}'
else
  echo "未安装 GNU parallel 或 PARALLEL_JOBS==1，使用 for 循环串行运行"
  for f in "${FASTAS[@]}"; do
    run_one_sample "$f"
  done
fi

# 合并结果
echo "合并分析结果..."

# 合并OCL结果
OCL_ALL="${OUTPUT_DIR}/All_OCL_results.tsv"
echo "Assembly	Best match locus	Best match type	Match confidence	Problems	Coverage	Identity	Length discrepancy	Expected genes in locus	Expected genes in locus, details	Missing expected genes	Other genes in locus	Other genes in locus, details	Expected genes outside locus	Expected genes outside locus, details	Other genes outside locus	Other genes outside locus, details" > "${OCL_ALL}"

shopt -s nullglob
for f in "${OUTPUT_DIR}/OCL_results/"*_OCL_results.tsv; do
  tail -n +2 "$f" >> "${OCL_ALL}"
done

# 合并K locus结果
K_ALL="${OUTPUT_DIR}/All_K_locus_results.tsv"
echo "Assembly	Best match locus	Best match type	Match confidence	Problems	Coverage	Identity	Length discrepancy	Expected genes in locus	Expected genes in locus, details	Missing expected genes	Other genes in locus	Other genes in locus, details	Expected genes outside locus	Expected genes outside locus, details	Other genes outside locus	Other genes outside locus, details" > "${K_ALL}"

for f in "${OUTPUT_DIR}/K_locus_results/"*_K_locus_results.tsv; do
  tail -n +2 "$f" >> "${K_ALL}"
done
shopt -u nullglob

## 删除中间结果目录
# rm -rf  "${OUTPUT_DIR}/OCL_results"
# rm -rf  "${OUTPUT_DIR}/K_locus_results"

echo "================================"
echo "Kaptive分析完成！"
echo "合并结果文件："
echo "- OCL合并结果：${OCL_ALL}"
echo "- K locus合并结果：${K_ALL}"
echo "（说明：已删除中间目录 OCL_results/ 与 K_locus_results/）"
echo "完成时间：$(date)"
