#!/usr/bin/env bash
set -euo pipefail

# === 输入与输出路径（按你的实际情况设置即可） ===
URL_LIST="/mnt/f/OneDrive/文档（科研）/脚本/Download/13-A.baumannii/4-注释/2-MLST/conf/AB_url.txt"
OUT_BASE="/mnt/f/OneDrive/文档（科研）/脚本/Download/13-A.baumannii/4-注释/2-MLST/download"

# === 目录结构 ===
OX_DIR="${OUT_BASE}/Oxford"
OX_ALLELES_DIR="${OX_DIR}/alleles"
PA_DIR="${OUT_BASE}/Pasteur"
PA_ALLELES_DIR="${PA_DIR}/alleles"

mkdir -p "${OX_ALLELES_DIR}" "${PA_ALLELES_DIR}"

download_file() {
  local url="$1"
  local out="$2"
  # 带断点续传、自动跟随跳转、失败重试、超时
  curl -L --fail --retry 3 --retry-delay 2 --connect-timeout 15 --max-time 600 \
       -H "Accept: */*" \
       -o "${out}.part" "${url}"
  mv -f "${out}.part" "${out}"
  echo "✓ ${url}  ->  ${out}"
}

# 读取 URL 列表并分类下载
while IFS= read -r url || [[ -n "${url}" ]]; do
  # 跳过空行和注释
  [[ -z "${url}" ]] && continue
  [[ "${url}" =~ ^# ]] && continue

  # Oxford profiles
  if [[ "${url}" == *"/schemes/1/profiles_csv" ]]; then
    out="${OX_DIR}/profiles_oxford.csv"
    download_file "${url}" "${out}"
    continue
  fi

  # Pasteur profiles
  if [[ "${url}" == *"/schemes/2/profiles_csv" ]]; then
    out="${PA_DIR}/profiles_pasteur.csv"
    download_file "${url}" "${out}"
    continue
  fi

  # Oxford loci alleles
  if [[ "${url}" == *"/loci/Oxf_"*"/alleles_fasta" ]]; then
    # 提取位点名，例如 Oxf_gltA
    locus="${url##*/loci/}"          # Oxf_gltA/alleles_fasta
    locus="${locus%%/*}"              # Oxf_gltA
    out="${OX_ALLELES_DIR}/${locus}.fasta"
    download_file "${url}" "${out}"
    continue
  fi

  # Pasteur loci alleles
  if [[ "${url}" == *"/loci/Pas_"*"/alleles_fasta" ]]; then
    locus="${url##*/loci/}"          # Pas_gltA/alleles_fasta
    locus="${locus%%/*}"              # Pas_gltA
    out="${PA_ALLELES_DIR}/${locus}.fasta"
    download_file "${url}" "${out}"
    continue
  fi

  echo "⚠️ 未识别的 URL 模式，跳过：${url}"
done < "${URL_LIST}"

# 合并各方案的 alleles 为单一 FASTA
# 若某些位点缺失不会报错（使用通配符和 cat 的条件判断）
ox_combined="${OX_DIR}/oxford_alleles.fasta"
pa_combined="${PA_DIR}/pasteur_alleles.fasta"

# 仅在有文件时才合并，避免 cat 报错
shopt -s nullglob
ox_files=( "${OX_ALLELES_DIR}"/Oxf_*.fasta )
pa_files=( "${PA_ALLELES_DIR}"/Pas_*.fasta )
shopt -u nullglob

if (( ${#ox_files[@]} > 0 )); then
  cat "${OX_ALLELES_DIR}"/Oxf_*.fasta > "${ox_combined}"
  echo "✓ 合并 Oxford alleles -> ${ox_combined}"
else
  echo "⚠️ 未发现 Oxford 等位基因 FASTA，未生成合并文件"
fi

if (( ${#pa_files[@]} > 0 )); then
  cat "${PA_ALLELES_DIR}"/Pas_*.fasta > "${pa_combined}"
  echo "✓ 合并 Pasteur alleles -> ${pa_combined}"
else
  echo "⚠️ 未发现 Pasteur 等位基因 FASTA，未生成合并文件"
fi

echo
echo "目录结构预览："
command -v tree >/dev/null 2>&1 && tree -a "${OUT_BASE}" || find "${OUT_BASE}" -maxdepth 3 -type f -print

echo
echo "全部完成 ✅"
