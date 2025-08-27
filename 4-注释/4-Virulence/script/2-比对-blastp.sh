#!/usr/bin/env bash
set -euo pipefail

# === 配置 ===
PROKKA_DIR="/mnt/d/1-鲍曼菌/注释prokka"
VFDB_DB="/mnt/f/OneDrive/文档（科研）/脚本/Download/13-A.baumannii/4-注释/4-Virulence/data/VFDB_2022_pro_combined"
OUT_DIR="/mnt/d/1-鲍曼菌/毒力因子"
JOBS="${JOBS:-0}"               # 并发任务数：0=parallel 默认（核数）
THREADS_PER_JOB="${THREADS_PER_JOB:-8}"  # 每个 blastp 的线程

mkdir -p "$OUT_DIR"

# 输出字段包含 stitle（库条目标题，常有基因/功能描述）
FMT='6 qseqid sseqid pident length qlen slen qstart qend sstart send bitscore evalue stitle'

# 收集所有 .faa
mapfile -d '' FAA_LIST < <(find "$PROKKA_DIR" -mindepth 2 -maxdepth 2 -type f -name "*.faa" -print0)
if (( ${#FAA_LIST[@]} == 0 )); then
  echo "WARN: ${PROKKA_DIR} 下没有找到 *.faa"
  exit 0
fi

blast_one() {
  local faa="$1"
  local base stem outtsv
  base="$(basename "$faa")"
  stem="${base%.faa}"
  outtsv="${OUT_DIR}/${stem}_vs_VFDB.tsv"

  echo ">>> ${stem}"
  blastp -query "$faa" -db "$VFDB_DB" \
    -evalue 1e-5 \
    -num_threads "${THREADS_PER_JOB}" \
    -outfmt "$FMT" \
    -out "$outtsv"
  echo "    -> $outtsv"
}
export -f blast_one
export OUT_DIR VFDB_DB THREADS_PER_JOB FMT

if command -v parallel >/dev/null 2>&1; then
  echo "[INFO] 使用 GNU parallel"
  if [[ "$JOBS" -gt 0 ]]; then
    printf '%s\0' "${FAA_LIST[@]}" | parallel -0 --bar -j "$JOBS" blast_one {}
  else
    printf '%s\0' "${FAA_LIST[@]}" | parallel -0 --bar blast_one {}
  fi
else
  echo "[INFO] 未检测到 parallel, 使用 xargs 并行"
  J="${JOBS}"; [[ "$J" -le 0 ]] && J="$(nproc --all 2>/dev/null || echo 4)"
  printf '%s\0' "${FAA_LIST[@]}" | xargs -0 -n1 -P "$J" -I{} bash -c 'blast_one "$@"' _ {}
fi

echo "✅ 全部 BLASTp 完成：${OUT_DIR}"

