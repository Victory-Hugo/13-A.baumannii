#!/usr/bin/env bash
set -euo pipefail

# === 配置 ===
PROKKA_DIR="/mnt/d/1-鲍曼菌/注释prokka"
VFDB_DB="/mnt/f/OneDrive/文档（科研）/脚本/Download/13-A.baumannii/4-注释/4-Virulence/data/VFDB_2022_pro_combined"
OUT_DIR="/mnt/d/1-鲍曼菌/毒力因子"
JOBS="${JOBS:-0}"               # 并发任务数：0=自动计算（见后）
THREADS_PER_JOB="${THREADS_PER_JOB:-1}"  # 每个 diamond 的线程（默认 1，更保守）

mkdir -p "$OUT_DIR"

# DIAMOND db 文件判断（支持用户提供 VFDB_DB 或 VFDB_DB.dmnd）
if [[ -f "${VFDB_DB}.dmnd" ]]; then
  DIAMOND_DB="${VFDB_DB}.dmnd"
else
  DIAMOND_DB="${VFDB_DB}"
fi

# 输出字段（DIAMOND 格式）
# DIAMOND 使用 --outfmt 6 表示表格格式，字段通过其他方式指定
OUTFMT='6'

# 收集所有 .faa
mapfile -d '' FAA_LIST < <(find "$PROKKA_DIR" -mindepth 2 -maxdepth 2 -type f -name "*.faa" -print0)
if (( ${#FAA_LIST[@]} == 0 )); then
  echo "WARN: ${PROKKA_DIR} 下没有找到 *.faa"
  exit 0
fi

# === 自动计算合适的 JOBS（避免超分配） ===
CORES="$(nproc --all 2>/dev/null || echo 4)"

# 数学表示（用代码块给出）
# JOBS = floor(CORES / THREADS_PER_JOB)    # 推荐设定（当用户未指定 JOBS 时）
# 判断超分配: JOBS * THREADS_PER_JOB <= CORES
#
# 以上为说明；下面是实际计算：
if [[ "${JOBS}" -le 0 ]]; then
  JOBS=$(( CORES / THREADS_PER_JOB ))
  (( JOBS < 1 )) && JOBS=1
fi

if (( JOBS * THREADS_PER_JOB > CORES )); then
  echo "WARN: 当前配置会导致超分配 (JOBS=${JOBS} * THREADS_PER_JOB=${THREADS_PER_JOB} > CORES=${CORES})."
  JOBS=$(( CORES / THREADS_PER_JOB ))
  (( JOBS < 1 )) && JOBS=1
  echo "INFO: 已将 JOBS 调整为 ${JOBS} 以避免超分配。"
fi

echo "[CONFIG] CORES=${CORES}, JOBS=${JOBS}, THREADS_PER_JOB=${THREADS_PER_JOB}"
echo "[DB] 使用 DIAMOND 数据库：${DIAMOND_DB}"

# 单个文件的比对函数（使用 diamond blastp）
diamond_one() {
  local faa="$1"
  local base stem outtsv
  base="$(basename "$faa")"
  stem="${base%.faa}"
  outtsv="${OUT_DIR}/${stem}_vs_VFDB.tsv"

  echo ">>> ${stem}"
  # 使用 --outfmt 6 表示表格格式；-p 为线程数
  diamond blastp \
    -q "$faa" \
    -d "$DIAMOND_DB" \
    -o "$outtsv" \
    -e 1e-5 \
    -p "${THREADS_PER_JOB}" \
    --outfmt "$OUTFMT"

  echo "    -> $outtsv"
}

export -f diamond_one
export OUT_DIR DIAMOND_DB THREADS_PER_JOB OUTFMT

# 并行执行（优先使用 GNU parallel）
if command -v parallel >/dev/null 2>&1; then
  echo "[INFO] 使用 GNU parallel 执行 DIAMOND"
  # 加上 --nice 以降低优先级，--joblog 便于事后检查
  if [[ "$JOBS" -gt 0 ]]; then
    printf '%s\0' "${FAA_LIST[@]}" | parallel -0 --bar -j "$JOBS" --nice 10 --joblog "${OUT_DIR}/parallel.joblog" diamond_one {}
  else
    printf '%s\0' "${FAA_LIST[@]}" | parallel -0 --bar --nice 10 --joblog "${OUT_DIR}/parallel.joblog" diamond_one {}
  fi
else
  echo "[INFO] 未检测到 parallel, 使用 xargs 并行"
  J="${JOBS}"; [[ "$J" -le 0 ]] && J="$(nproc --all 2>/dev/null || echo 4)"
  printf '%s\0' "${FAA_LIST[@]}" | xargs -0 -n1 -P "$J" -I{} bash -c 'diamond_one "$@"' _ {}
fi

echo "✅ 全部 DIAMOND 比对完成：${OUT_DIR}"
