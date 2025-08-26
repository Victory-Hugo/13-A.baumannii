#!/bin/bash
#? 运行时需要确保软件已经安装
#! 并且运行时需要联网！

#=== 配置区（按需修改） ===
#* 示例：
#* /mnt/d/1-鲍曼菌/注释prokka
#* ├── ERR1946991
#* │   ├── ERR1946991.faa
#* │   ├── ERR1946991.fna
#* │   ├── ERR1946991.gff
#* └── ERR1946999
#*    ├── ERR1946999.faa
#*    ├── ERR1946999.fna
#*    ├── ERR1946999.gff
PROKKA_OUT_DIR="/mnt/d/1-鲍曼菌/注释prokka"    # Prokka 输出的父目录（其下每个样本一个子目录）
OUT_DIR="/mnt/d/1-鲍曼菌/抗生素耐药"           # 结果输出目录
THREADS_PER_JOB="${THREADS_PER_JOB:-8}"        # amrfinder 的 --threads（每个并发任务用多少线程）
JOBS="${JOBS:-0}"                               # 并发任务数；0 表示让 parallel 自动取 CPU 核心数；xargs 时会用 nproc
#（可选）显式指定 AMRFinder 数据库目录；若留空将使用默认查找
AMRFINDER_DB_DIR="${AMRFINDER_DB_DIR:-}"

#=== 环境准备 ===
unset http_proxy || true
unset https_proxy || true
mkdir -p "$OUT_DIR"

# 如果指定了数据库路径，导出给 amrfinder 使用
if [[ -n "${AMRFINDER_DB_DIR}" ]]; then
  export AMRFINDER_DB="${AMRFINDER_DB_DIR}"
fi

#=== 收集样本：查找所有 *.gff（Prokka）===
# 形态：/path/注释prokka/<BASENAME>/<BASENAME>.gff
mapfile -d '' GFFS < <(find "$PROKKA_OUT_DIR" -mindepth 2 -maxdepth 2 -type f -name "*.gff" -print0)

if (( ${#GFFS[@]} == 0 )); then
  echo "WARN: 在 ${PROKKA_OUT_DIR} 下未找到任何 *.gff（检查路径/权限/文件）"
  exit 0
fi

echo "[INFO] 发现样本数：${#GFFS[@]}"
echo "[INFO] 输出目录：${OUT_DIR}"
echo "[INFO] 每任务线程数：${THREADS_PER_JOB}"
[[ -n "${AMRFINDER_DB_DIR}" ]] && echo "[INFO] 使用数据库：${AMRFINDER_DB_DIR}"
echo

#=== 定义处理单个样本的函数 ===
run_one() {
  local gff="$1"
  local dir base fna faa out

  dir="$(dirname "$gff")"
  base="$(basename "${gff%.gff}")"
  fna="${dir}/${base}.fna"
  faa="${dir}/${base}.faa"
  out="${OUT_DIR}/${base}_AMRFinder.tsv"

  # 基础检查
  if [[ ! -s "$fna" ]]; then
    echo "[WARN] 缺少核酸文件：$fna —— 跳过 ${base}" >&2
    return 0
  fi
  if [[ ! -s "$faa" ]]; then
    echo "[WARN] 缺少蛋白文件：$faa —— 跳过 ${base}" >&2
    return 0
  fi

  echo ">>> 运行样本：${base}"
  echo "    fna: $fna"
  echo "    faa: $faa"
  echo "    gff: $gff"
  [[ -n "${AMRFINDER_DB_DIR}" ]] && echo "    db : ${AMRFINDER_DB_DIR}"

    # --annotation_format prokka：告诉 AMRFinder 这是 Prokka 风格注释
    # --plus：启用 PLUS 库（应激/金属/杀生物剂等扩展）
    #* --plus 加强模式，提供来自“Plus”基因的结果，例如毒力因子、应激反应基因等。
    #* -p RA-RCAD.faa 输入蛋白序列文件
    #* -n  RA-RCAD.ffn 输入CDS核酸序列文件
    #* -g RA-RCAD_amrfinder.gff 输入gff格式的基因组注释文件
    #* --threads 8 8核心cpu 用于加快速度 默认使用4 线程运算
    #* -o RA-RCAD_AMRFinder_out_all.xls 检索结果输出到RA-RCAD_AMRFinder_out_all.xls文件

  amrfinder \
    --plus \
    -n "$fna" \
    -p "$faa" \
    -g "$gff" \
    --annotation_format prokka \
    --threads "${THREADS_PER_JOB}" \
    -o "$out"

  echo "    完成 -> $out"
}
export -f run_one
export OUT_DIR THREADS_PER_JOB AMRFINDER_DB_DIR

#=== 并行执行 ===
if command -v parallel >/dev/null 2>&1; then
  echo "[INFO] 使用 GNU parallel 并行执行"
  if [[ "${JOBS}" -gt 0 ]]; then
    printf '%s\0' "${GFFS[@]}" | parallel -0 --bar -j "${JOBS}" run_one {}
  else
    printf '%s\0' "${GFFS[@]}" | parallel -0 --bar run_one {}
  fi
else
  echo "[INFO] 未检测到 GNU parallel，退化为 xargs 并行"
  # xargs 并发数：若未设置 JOBS 或 JOBS<=0，则取 nproc
  if [[ "${JOBS}" -le 0 ]]; then
    JOBS="$(nproc --all 2>/dev/null || echo 4)"
  fi
  printf '%s\0' "${GFFS[@]}" | xargs -0 -n1 -P "${JOBS}" -I{} bash -c 'run_one "$@"' _ {}
fi

echo
echo "✅ 全部完成，结果在：${OUT_DIR}"
