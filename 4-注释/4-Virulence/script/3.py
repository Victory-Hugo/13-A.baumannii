#!/usr/bin/env python3
# -*- coding: utf-8 -*-
import pandas as pd
from pathlib import Path
import glob

# === 配置 ===
IN_DIR = Path("/mnt/d/1-鲍曼菌/毒力因子")     # 01 脚本输出目录
OUT_DIR = IN_DIR                              # 也可以改
PID_TH = 90.0
COV_TH = 60.0

# 读取所有 *_vs_VFDB.tsv
files = sorted(glob.glob(str(IN_DIR / "*_vs_VFDB.tsv")))
if not files:
    raise SystemExit(f"No BLAST results found in {IN_DIR}")

all_hits = []
for f in files:
    sample = Path(f).name.replace("_vs_VFDB.tsv","")
    df = pd.read_csv(f, sep='\t', header=None,
                     names=["qseqid","sseqid","pident","length","qlen","slen",
                            "qstart","qend","sstart","send","bitscore","evalue","stitle"])
    # 覆盖度（对 query：你的蛋白）
    df["qcov"] = df["length"] / df["qlen"] * 100.0

    # 阈值过滤
    df = df[(df["pident"] >= PID_TH) & (df["qcov"] >= COV_TH)].copy()

    # 同一个 query 可能多条命中，保留 bitscore 最大（最优）
    df = df.sort_values(["qseqid","bitscore"], ascending=[True, False]) \
           .drop_duplicates(subset=["qseqid"], keep="first")

    df.insert(0, "sample", sample)
    all_hits.append(df)

if not all_hits:
    raise SystemExit("No hits passed filters.")

hits = pd.concat(all_hits, ignore_index=True)

# 输出筛选后的长表
out_long = OUT_DIR / "VFDB_hits_filtered.tsv"
hits.to_csv(out_long, sep='\t', index=False)

# 生成 presence/absence 矩阵（样本 x VFDB条目）
# 这里用 sseqid 作为列名（唯一）；也可映射为基因符号（若 stitle 中可解析）
mat = hits.assign(presence=1).pivot_table(
    index="sample", columns="sseqid", values="presence", aggfunc="max", fill_value=0
)
out_mat = OUT_DIR / "VFDB_presence_absence.tsv"
mat.to_csv(out_mat, sep='\t')

print(f"[Wrote] {out_long}")
print(f"[Wrote] {out_mat}")
