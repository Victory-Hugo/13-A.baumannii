#!/usr/bin/env bash
# rename_fasta_headers_to_dir.sh
# 非递归、路径写死、将修改后的文件保存到新目录 /mnt/d/1-ABaumannii/Assemble_rename
# 每个 .fasta 文件内以 '^>' 开头的 header 会被替换为:
# >basename_1
# >basename_2
# ...
# 原始文件不被修改，输出文件会覆盖目标目录下同名文件（如已存在）

set -euo pipefail

SRC_DIR="/mnt/d/1-ABaumannii/Assemble"
OUT_DIR="/mnt/d/1-ABaumannii/Assemble_rename"

if [ ! -d "$SRC_DIR" ]; then
  echo "错误：源目录不存在：$SRC_DIR" >&2
  exit 1
fi

# 创建输出目录（如果不存在）
mkdir -p "$OUT_DIR"

# 非递归读取 *.fasta（支持文件名带空格）
shopt -s nullglob
files=("$SRC_DIR"/*.fasta)
shopt -u nullglob

if [ ${#files[@]} -eq 0 ]; then
  echo "未找到任何 .fasta 文件（目录：$SRC_DIR）"
  exit 0
fi

processed_files=0
processed_seqs_total=0

for f in "${files[@]}"; do
  # 取不带扩展名的 basename
  base="$(basename "$f")"
  base="${base%.*}"

  # 输出路径（与源文件同名，放在 OUT_DIR）
  out="$OUT_DIR/$(basename "$f")"

  # 在输出目录中创建临时文件，避免跨文件系统问题
  tmp="$(mktemp "$OUT_DIR/.${base}.tmp.XXXX")"

  # 用 awk 只替换以 '^>' 开头的行，按文件内出现顺序编号
  awk -v b="$base" 'BEGIN{i=0} /^>/ { i++; print ">" b "_" i; next } { print }' "$f" > "$tmp"

  # 如果文件为 Windows CRLF，去掉行尾的 \r（安全处理）
  sed -i 's/\r$//' "$tmp" || true

  # 将临时文件移动为目标输出文件（覆盖）
  mv -f -- "$tmp" "$out"

  # 尝试保留原文件的权限和时间戳（尽量保持属性一致）
  # 如果系统不支持 --reference（极少见），这些命令会失败；使用 || true 忽略错误但尽力保留
  chmod --reference="$f" "$out" 2>/dev/null || true
  touch -r "$f" "$out" 2>/dev/null || true

  # 统计 header 数量
  n="$(grep -c '^>' -- "$out" || true)"
  echo "已写出: $out -> 重命名序列: $n"

  processed_files=$((processed_files+1))
  processed_seqs_total=$((processed_seqs_total + n))
done

echo "完成。共处理文件: ${processed_files}, 重命名序列总计: ${processed_seqs_total}"
