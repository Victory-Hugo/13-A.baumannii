#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
统一规范 PubMLST REST 下载的 FASTA header，并构建 BLAST 数据库（去重+稳健解析）。
- 目录结构（既有）：
  BASE/
    Oxford/
      alleles/  (Oxf_*.fasta)
      profiles_oxford.csv
    Pasteur/
      alleles/  (Pas_*.fasta)
      profiles_pasteur.csv

- 输出：
  Oxford/oxford_alleles.norm.fasta
  Pasteur/pasteur_alleles.norm.fasta
  Oxford/blastdb/oxford.*
  Pasteur/blastdb/pasteur.*

"""

import re
import sys
import subprocess
from pathlib import Path

# === 修改这里：你的下载根目录 ===
BASE = Path("/mnt/f/OneDrive/文档（科研）/脚本/Download/13-A.baumannii/4-注释/2-MLST/download")

# === 是否使用 -parse_seqids 构建 BLAST 数据库（建议 True；若仍报重复可设为 False） ===
USE_PARSE_SEQIDS = True

# ============ 工具函数 ============

def read_fasta(path):
    """简易 FASTA 读取器，yield (header, seq)；header 不含 '>'。"""
    header = None
    seq_chunks = []
    with path.open() as fh:
        for line in fh:
            line = line.rstrip("\n\r")
            if not line:
                continue
            if line.startswith(">"):
                if header is not None:
                    yield header, "".join(seq_chunks)
                header = line[1:].strip()
                seq_chunks = []
            else:
                seq_chunks.append(line.strip())
        if header is not None:
            yield header, "".join(seq_chunks)

def extract_allele_number(raw_header):
    """
    尽量稳健地从 header 中提取 allele 号：
      1) 若已有 locus_123 形式，取最后一个数字
      2) 否则，在整行中查找所有整数，取 **最后一个** 作为 allele 号
      3) 若仍无数字，返回 None（由调用方用递增计数兜底）
    """
    # 直接抓取 header 末尾数字
    m = re.search(r'(\d+)(?:\D*)$', raw_header)
    if m:
        return int(m.group(1))
    # 次优：抓所有数字，取最后一个
    nums = re.findall(r'(\d+)', raw_header)
    if nums:
        return int(nums[-1])
    return None

def normalize_one_file(fasta_path, locus, seen_ids, out_handle):
    """
    处理单个位点 FASTA：
      - 提取 allele 号
      - 生成 ID: {locus}_{allele}；若重复则加 |dupN
      - 写入到 out_handle
      - 返回统计信息（条目数、重复数）
    """
    n = 0
    dups = 0
    auto_idx = 0
    for raw_header, seq in read_fasta(fasta_path):
        n += 1
        allele = extract_allele_number(raw_header)
        if allele is None:
            # 没法提取数字，用顺序号兜底（从1开始递增），并警告
            auto_idx += 1
            allele = auto_idx
            # 你也可以在此处 print 提示：某条记录未识别到数字
            # print(f"[warn] {fasta_path.name} 第{n}条未检测到数字，自动赋值 allele={allele}", file=sys.stderr)

        base_id = f"{locus}_{allele}"
        uid = base_id
        if uid in seen_ids:
            # 重复，追加 |dupN
            dups += 1
            k = 2
            while f"{base_id}|dup{k}" in seen_ids:
                k += 1
            uid = f"{base_id}|dup{k}"
        seen_ids.add(uid)

        # 写出
        out_handle.write(f">{uid}\n")
        # 每行不换行也可以，若想换行为60列，可自行分割；对 makeblastdb 无影响
        out_handle.write(seq + "\n")
    return n, dups

def build_blastdb(fasta_path, out_prefix, use_parse=True):
    """调用 makeblastdb 构建核酸库。"""
    # 先清理旧索引
    for ext in (".nhr", ".nin", ".nsq", ".ndb", ".not", ".ntf", ".nto", ".nal"):
        p = Path(str(out_prefix) + ext)
        if p.exists():
            try:
                p.unlink()
            except Exception:
                pass
    cmd = [
        "makeblastdb",
        "-in", str(fasta_path),
        "-dbtype", "nucl",
        "-out", str(out_prefix),
    ]
    if use_parse:
        cmd.insert(1, "-parse_seqids")  # 放前面或后面均可

    print(">>", " ".join(cmd))
    subprocess.run(cmd, check=True)

# ============ 主流程 ============

def process_scheme(scheme_name, subdir_prefix):
    """
    处理一个方案（Oxford 或 Pasteur）：
      - 遍历 alleles/*.fasta
      - 规范化并合并为 *.norm.fasta
      - 构建 BLAST 数据库
    """
    scheme_dir = BASE / scheme_name
    alleles_dir = scheme_dir / "alleles"
    if not alleles_dir.is_dir():
        print(f"[ERROR] 未找到目录：{alleles_dir}", file=sys.stderr)
        return

    if subdir_prefix == "Oxf":
        norm_out = scheme_dir / "oxford_alleles.norm.fasta"
        db_prefix = scheme_dir / "blastdb" / "oxford"
    else:
        norm_out = scheme_dir / "pasteur_alleles.norm.fasta"
        db_prefix = scheme_dir / "blastdb" / "pasteur"

    db_prefix.parent.mkdir(parents=True, exist_ok=True)

    fasta_files = sorted(alleles_dir.glob(f"{subdir_prefix}_*.fasta"))
    if not fasta_files:
        print(f"[WARN] 未在 {alleles_dir} 找到 {subdir_prefix}_*.fasta", file=sys.stderr)

    seen_ids = set()
    total_seqs = 0
    total_dups = 0

    with norm_out.open("w") as out:
        for f in fasta_files:
            locus = f.stem  # 如 Oxf_gltA / Pas_cpn60
            n, d = normalize_one_file(f, locus, seen_ids, out)
            total_seqs += n
            total_dups += d
            print(f"✓ {scheme_name}: {f.name} -> {n} 条，重复 {d} 条（自动去重）")

    print(f"✓ 生成 {norm_out}（合计 {total_seqs} 条，去重 {total_dups} 条）")

    # 构建 BLAST 数据库
    try:
        build_blastdb(norm_out, db_prefix, use_parse=USE_PARSE_SEQIDS)
        print(f"✓ {scheme_name} BLAST 数据库完成：{db_prefix}")
    except subprocess.CalledProcessError as e:
        print(f"[ERROR] makeblastdb 失败（{scheme_name}）：{e}.", file=sys.stderr)
        if USE_PARSE_SEQIDS:
            print("建议：将 USE_PARSE_SEQIDS 改为 False 再运行一次（避免因重复 ID 终止）。", file=sys.stderr)
        sys.exit(2)

def main():
    print(f"[INFO] BASE = {BASE}")
    process_scheme("Oxford",  "Oxf")
    process_scheme("Pasteur", "Pas")
    print("全部完成 ✅")

if __name__ == "__main__":
    main()
