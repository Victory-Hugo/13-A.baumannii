#!/usr/bin/env bash
set -euo pipefail

# 脚本名称: 2-比对-diamond.sh

# 用途:
#   使用 DIAMOND 工具对 Prokka 注释生成的蛋白质序列 (*.faa) 与 VFDB 毒力因子数据库进行批量比对，结果输出为表格格式（.tsv）。

# 主要流程:
#   1. 配置输入/输出路径、数据库路径、并发参数。
#   2. 自动检测可用 CPU 核心数，合理分配并发任务数与每任务线程数，避免超分配。
#   3. 收集所有待比对的 .faa 文件。
#   4. 判断 DIAMOND 数据库文件（支持 .dmnd 格式）。
#   5. 定义单文件比对函数 diamond_one，调用 diamond blastp 进行比对。
#   6. 优先使用 GNU parallel 并行执行比对任务，若未安装则使用 xargs。
#   7. 输出比对结果至指定目录，并生成日志。

# 参数说明:
#   PROKKA_DIR         - Prokka 注释结果目录，包含待比对的 .faa 文件。
#   VFDB_DB            - VFDB 毒力因子数据库路径（支持 .dmnd）。
#   OUT_DIR            - 比对结果输出目录。
#   JOBS               - 并发任务数（默认自动计算）。
#   THREADS_PER_JOB    - 每个 DIAMOND 任务使用的线程数（默认 1）。

# 依赖:
#   - diamond
#   - GNU parallel（推荐，自动检测）
#   - xargs（备选）

# 输出:
#   - 每个 .faa 文件对应一个 _vs_VFDB.tsv 比对结果文件，存放于 OUT_DIR。
#   - 并行执行日志（parallel.joblog）。

# 注意事项:
#   - 自动避免超分配 CPU 资源。
#   - 若 PROKKA_DIR 下无 .faa 文件则提前退出。
#   - 支持用户自定义并发参数，建议根据实际硬件调整。

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
