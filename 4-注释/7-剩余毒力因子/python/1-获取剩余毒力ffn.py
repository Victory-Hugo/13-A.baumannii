#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
process_one.py
功能（严格按原始逻辑，不做修正）：
  - 接受一个命令行参数 BASENAME
  - 从 PROKKA_DIR/BASENAME/BASENAME.ffn 读取原始序列
  - 将原始序列 ID 前加上 "BASENAME|"（与原脚本相同）
  - 读取 K_DIR/{BASENAME}_kaptive_results.fna 与 OCL_DIR/{BASENAME}_kaptive_results.fna
    并把每个 seq id 在 ":" 处截断 (seq_id.split(":")[0])
  - 求 (带前缀的 origin ids) 与 (K/OCL ids 的并集) 的差集
  - 把差集内每个 id 去掉前缀 "|" 之前的部分（split("|")[1]）
  - 从原始 ffn 中提取对应序列（使用 record.id.split("|")[0] 做匹配）
  - 将结果写到 OUTPUT_DIR/{BASENAME}.Remain.ffn
注意：上面流程与你给的原始脚本行为一致（包括可能看起来矛盾的 id 处理），**不做任何修正**。
运行前需通过环境变量提供：PROKKA_DIR, K_DIR, OCL_DIR, OUTPUT_DIR
"""

import os
import sys
from Bio import SeqIO

def eprint(*args, **kwargs):
    print(*args, file=sys.stderr, **kwargs)

def main():
    if len(sys.argv) != 2:
        eprint("Usage: process_one.py BASENAME")
        sys.exit(2)

    BASENAME = sys.argv[1]

    PROKKA_DIR = os.environ.get("PROKKA_DIR")
    K_DIR = os.environ.get("K_DIR")
    OCL_DIR = os.environ.get("OCL_DIR")
    OUTPUT_DIR = os.environ.get("OUTPUT_DIR")

    for name, val in (("PROKKA_DIR", PROKKA_DIR), ("K_DIR", K_DIR),
                      ("OCL_DIR", OCL_DIR), ("OUTPUT_DIR", OUTPUT_DIR)):
        if not val:
            eprint(f"Error: environment variable {name} is not set.")
            sys.exit(3)

    origin_file = os.path.join(PROKKA_DIR, BASENAME, f"{BASENAME}.ffn")
    k_file = os.path.join(K_DIR, f"{BASENAME}_kaptive_results.fna")
    ocl_file = os.path.join(OCL_DIR, f"{BASENAME}_kaptive_results.fna")

    if not os.path.isfile(origin_file):
        eprint(f"[{BASENAME}] 原始 ffn 文件不存在：{origin_file}，跳过。")
        return

    # 读取 origin 的 seq ids，并按原脚本加前缀 BASENAME|
    try:
        seq_ids = [rec.id for rec in SeqIO.parse(origin_file, "fasta")]
    except Exception as e:
        eprint(f"[{BASENAME}] 读取 origin 文件失败: {e}")
        return

    seq_ids = [f"{BASENAME}|{sid}" for sid in seq_ids]   # **保留原始脚本的行为**

    # 读取 K 的 seq ids（如存在）
    K_seq_ids = []
    if os.path.isfile(k_file):
        try:
            K_seq_ids = [rec.id for rec in SeqIO.parse(k_file, "fasta")]
            K_seq_ids = [sid.split(":")[0] for sid in K_seq_ids]  # 保留原始脚本行为
        except Exception as e:
            eprint(f"[{BASENAME}] 读取 K 文件失败: {e}，当作空集合处理。")
            K_seq_ids = []
    else:
        eprint(f"[{BASENAME}] 未找到 K 文件：{k_file} （当作空集合）")

    # 读取 OCL 的 seq ids（如存在）
    OCL_seq_ids = []
    if os.path.isfile(ocl_file):
        try:
            OCL_seq_ids = [rec.id for rec in SeqIO.parse(ocl_file, "fasta")]
            OCL_seq_ids = [sid.split(":")[0] for sid in OCL_seq_ids]  # 保留原始脚本行为
        except Exception as e:
            eprint(f"[{BASENAME}] 读取 OCL 文件失败: {e}，当作空集合处理。")
            OCL_seq_ids = []
    else:
        eprint(f"[{BASENAME}] 未找到 OCL 文件：{ocl_file} （当作空集合）")

    # 求并集与差集（严格按原始逻辑）
    OCL_K_union_ids = set(OCL_seq_ids) | set(K_seq_ids)
    OCL_K_diff_ids = set(seq_ids) - OCL_K_union_ids

    # 去掉前缀 'BASENAME|' 的左侧部分，保留原脚本的 split("|")[1]
    OCL_K_diff_ids = [sid.split("|")[1] for sid in OCL_K_diff_ids]

    # 根据 OCL_K_diff_ids 提取出 origin 中对应的序列
    # NOTE: 保留原脚本逻辑：使用 record.id.split("|")[0] 来判断（严格复刻）
    extracted = []
    try:
        for rec in SeqIO.parse(origin_file, "fasta"):
            key = rec.id.split("|")[0]
            if key in OCL_K_diff_ids:
                extracted.append(rec)
    except Exception as e:
        eprint(f"[{BASENAME}] 从 origin 提取序列失败: {e}")
        return

    # 输出目录准备
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    out_path = os.path.join(OUTPUT_DIR, f"{BASENAME}.Remain.ffn")

    if extracted:
        SeqIO.write(extracted, out_path, "fasta")
        eprint(f"[{BASENAME}] 导出 {len(extracted)} 条序列到 {out_path}")
    else:
        # 若没有序列也写出空文件（保留行为可选）
        SeqIO.write([], out_path, "fasta")
        eprint(f"[{BASENAME}] 没有匹配的序列，写出空文件 {out_path}")

if __name__ == "__main__":
    main()
