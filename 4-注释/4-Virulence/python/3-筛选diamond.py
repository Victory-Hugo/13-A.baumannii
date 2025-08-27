#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
vfdb_filter_parallel.py
将 DIAMOND blastp outfmt=6 的 .tsv 批量过滤为满足 identity>=90% 且 query_coverage>=60% 的简要 txt 列表。
用法示例：
  # 处理单个文件
  4-注释/4-Virulence/script/3-筛选.py /path/to/file.tsv /output/dir

  # 处理整个目录（并行）
  4-注释/4-Virulence/script/3-筛选.py /path/to/tsv_dir /output/dir -j 8
"""
import argparse
import os
import sys
from pathlib import Path
from concurrent.futures import ProcessPoolExecutor, as_completed
import pandas as pd

# 映射 DIAMOND outfmt=6 的列（header=None 时的整数列 -> 名称）
# DIAMOND 默认输出格式只有12列，不包含 stitle
COL_MAP = {
    0: 'qseqid', 1: 'sseqid', 2: 'pident', 3: 'length',
    4: 'qlen', 5: 'slen', 6: 'qstart', 7: 'qend',
    8: 'sstart', 9: 'send', 10: 'bitscore', 11: 'evalue'
}

# 过滤阈值（可改）
ID_THRESH = 90.0      # identity % >= 90.0
COV_Q_THRESH = 60.0   # query coverage % >= 60.0

def process_file(in_path: Path, out_dir: Path) -> str:
    """
    处理单个 tsv 文件，写入 out_dir/{basename}.txt
    返回写入的输出路径（字符串），若跳过则返回空字符串。
    """
    try:
        # 支持压缩文件（pandas 会根据后缀自动推断）
        # 注意：假设文件为无表头的 DIAMOND outfmt=6（12 列）
        df = pd.read_csv(in_path, sep='\t', header=None, compression='infer', dtype=str, low_memory=False)
    except Exception as e:
        return f"ERROR: 读取 {in_path} 失败: {e}"

    # 检查列数，DIAMOND 默认输出 12 列
    expected_cols = 12
    if df.shape[1] < expected_cols:
        # 用 NaN 补齐到 12 列
        for i in range(df.shape[1], expected_cols):
            df[i] = pd.NA
    
    # 只取前 12 列，按 DIAMOND outfmt=6 顺序重命名
    df = df.iloc[:, :expected_cols].rename(columns=COL_MAP)

    # 将需要的列转换为数值（pident, length, qlen, slen）
    for col in ('pident', 'length', 'qlen', 'slen'):
        df[col] = pd.to_numeric(df[col], errors='coerce').fillna(0.0)

    # identity 直接来自 pident
    df['identity_pct'] = df['pident']

    # coverage (query) = length / qlen
    # 数学公式：
    # coverage_query = length / qlen
    # coverage_query_pct = (length / qlen) * 100.0
    df['coverage_q_pct'] = 0.0
    nonzero_qlen = df['qlen'] != 0
    df.loc[nonzero_qlen, 'coverage_q_pct'] = (df.loc[nonzero_qlen, 'length'] / df.loc[nonzero_qlen, 'qlen']) * 100.0

    # 过滤
    filtered = df[(df['identity_pct'] >= ID_THRESH) & (df['coverage_q_pct'] >= COV_Q_THRESH)].copy()

    # 选择并去重：qseqid, sseqid（DIAMOND 默认不输出 stitle）
    # 由于没有 stitle，我们只输出 qseqid 和 sseqid
    out_df = filtered.loc[:, ['qseqid', 'sseqid']].drop_duplicates()

    # 准备输出路径
    base = in_path.name
    # 移除常见的复合后缀 .tsv.gz -> 则得到 basename 去掉 .tsv(.gz)
    for ext in ('.tsv.gz', '.tsv', '.txt.gz', '.txt'):
        if base.endswith(ext):
            base = base[: -len(ext)]
            break
    out_path = out_dir / f"{base}.txt"

    # 写入（包含表头，与原行为一致），制表符分隔
    try:
        out_df.to_csv(out_path, sep='\t', index=False)
        return str(out_path)
    except Exception as e:
        return f"ERROR: 写入 {out_path} 失败: {e}"

def gather_input_files(input_path: Path):
    """
    如果 input_path 是文件 -> 返回 [file]
    如果是目录 -> 返回目录下所有 *.tsv 和 *.tsv.gz 文件（递归非必须：只当前目录）
    """
    if input_path.is_file():
        return [input_path]
    elif input_path.is_dir():
        files = sorted([p for p in input_path.iterdir() if p.is_file() and p.suffix in ('.tsv', '.gz', '.txt') or p.name.endswith('.tsv.gz')])
        # 更稳妥的筛选：包含 .tsv 或 .tsv.gz 的文件
        files = [p for p in files if '.tsv' in p.name]
        return files
    else:
        return []

def main():
    parser = argparse.ArgumentParser(description="从 DIAMOND outfmt=6 TSV 中筛选 identity>=90 & coverage(query)>=60 的简要列表（并行）")
    parser.add_argument('input', help='输入文件（.tsv）或包含多个 .tsv 的目录')
    parser.add_argument('outdir', help='输出目录（会自动创建）')
    parser.add_argument('-j', '--jobs', type=int, default=0, help='并发作业数，0 或省略表示使用 CPU 核心数')
    args = parser.parse_args()

    in_path = Path(args.input).expanduser()
    out_dir = Path(args.outdir).expanduser()
    out_dir.mkdir(parents=True, exist_ok=True)

    files = gather_input_files(in_path)
    if not files:
        print(f"[WARN] 未找到要处理的文件：{in_path}", file=sys.stderr)
        sys.exit(1)

    max_workers = args.jobs if args.jobs and args.jobs > 0 else (os.cpu_count() or 1)
    print(f"[INFO] 发现 {len(files)} 个文件，将使用 {max_workers} 个 worker 并行处理...")

    results = []
    with ProcessPoolExecutor(max_workers=max_workers) as exe:
        future_to_path = {exe.submit(process_file, p, out_dir): p for p in files}
        for future in as_completed(future_to_path):
            p = future_to_path[future]
            try:
                res = future.result()
            except Exception as exc:
                print(f"[ERROR] 文件 {p} 处理失败: {exc}", file=sys.stderr)
            else:
                print(f"{p.name} -> {res}")
                results.append(res)

    print("[DONE] 全部任务提交完毕。")

if __name__ == "__main__":
    main()
