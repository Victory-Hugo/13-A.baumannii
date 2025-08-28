#!/usr/bin/env bash
set -euo pipefail

# === 配置区（按需改路径） ===
BASE="/mnt/f/OneDrive/文档（科研）/脚本/Download/13-A.baumannii/4-注释/2-MLST/download"
OX_DB="${BASE}/Oxford/blastdb/oxford"
PA_DB="${BASE}/Pasteur/blastdb/pasteur"
IN_DIR="/mnt/d/1-ABaumannii/Assemble_rename"
OUT_DIR="/mnt/d/1-ABaumannii/MLST"

# 并发度（可改），parallel 存在时生效；默认为 CPU 核心数
PARALLEL_JOBS="${PARALLEL_JOBS:-0}"   # 0 表示让 parallel 自定（= 核心数）
# BLAST 输出格式
FMT='6 qseqid sseqid pident length qlen slen qstart qend sstart send bitscore evalue'

# === 准备 ===
mkdir -p "${OUT_DIR}"

if [[ ! -f "${OX_DB}.nhr" && ! -f "${OX_DB}.nal" ]]; then
  echo "ERROR: 未发现 Oxford BLAST 库索引（${OX_DB}.*），请先构建。" >&2
  exit 1
fi
if [[ ! -f "${PA_DB}.nhr" && ! -f "${PA_DB}.nal" ]]; then
  echo "ERROR: 未发现 Pasteur BLAST 库索引（${PA_DB}.*），请先构建。" >&2
  exit 1
fi
if [[ ! -d "${IN_DIR}" ]]; then
  echo "ERROR: 输入目录不存在：${IN_DIR}" >&2
  exit 1
fi

echo "[INFO] 输入目录：${IN_DIR}"
echo "[INFO] 输出目录：${OUT_DIR}"
echo "[INFO] 使用库："
echo "       Oxford:  ${OX_DB}"
echo "       Pasteur: ${PA_DB}"
echo

# === 构造输入文件列表（null分隔，含大小写扩展名） ===
# 只在 IN_DIR 的第一层找文件；如需递归把 -maxdepth 1 去掉。
mapfile -d '' files < <(
  find "${IN_DIR}" -maxdepth 1 -type f \
    \( -iname '*.fasta' -o -iname '*.fa' -o -iname '*.fna' -o -iname '*.fas' \) -print0
)

if (( ${#files[@]} == 0 )); then
  echo "WARN: 在 ${IN_DIR} 下未找到 fasta/fa/fna/fas 文件。"
  exit 0
fi

echo "[INFO] 待处理文件数：${#files[@]}"
echo

# === 定义处理单个文件的函数 ===
process_one() {
  local QUERY="$1"
  local OX_DB="$2"
  local PA_DB="$3"
  local OUT_DIR="$4"
  local FMT="$5"

  local base stem out_ox out_pa
  base="$(basename -- "$QUERY")"
  stem="${base%.*}"
  out_ox="${OUT_DIR}/${stem}.oxford_vs_query.b6"
  out_pa="${OUT_DIR}/${stem}.pasteur_vs_query.b6"

  echo ">>> 处理：${base}"
  # Oxford
  blastn -query "$QUERY" -db "$OX_DB" -task blastn -evalue 1e-20 -max_target_seqs 50 -outfmt "$FMT" > "$out_ox"
  # Pasteur
  blastn -query "$QUERY" -db "$PA_DB" -task blastn -evalue 1e-20 -max_target_seqs 50 -outfmt "$FMT" > "$out_pa"
  echo "完成：${stem}"
}

export -f process_one
export OX_DB PA_DB OUT_DIR FMT

# === 并行执行 ===
if command -v parallel >/dev/null 2>&1; then
  echo "[INFO] 使用 GNU parallel 并行运行"
  # jobs=0 表示让 parallel 用默认（通常=核心数）；>0 则指定并发
  if [[ "${PARALLEL_JOBS}" -gt 0 ]]; then
    printf '%s\0' "${files[@]}" | parallel -0 --bar -j "${PARALLEL_JOBS}" \
      process_one {} "${OX_DB}" "${PA_DB}" "${OUT_DIR}" "${FMT}"
  else
    printf '%s\0' "${files[@]}" | parallel -0 --bar \
      process_one {} "${OX_DB}" "${PA_DB}" "${OUT_DIR}" "${FMT}"
  fi
else
  echo "[INFO] 未检测到 GNU parallel，退化为 xargs 并行（进度条不可用）"
  # xargs -P：并发数取 CPU 核心数；可以用环境变量控制
  J="${PARALLEL_JOBS}"; [[ "$J" -le 0 ]] && J="$(nproc --all 2>/dev/null || echo 4)"
  printf '%s\0' "${files[@]}" | xargs -0 -n1 -P "$J" -I{} bash -c \
    'process_one "$1" "$2" "$3" "$4" "$5"' _ {} "${OX_DB}" "${PA_DB}" "${OUT_DIR}" "${FMT}"
fi

echo
echo "全部完成 ✅   输出位置：${OUT_DIR}"
