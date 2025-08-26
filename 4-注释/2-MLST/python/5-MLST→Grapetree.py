#!/usr/bin/env python3
# -*- coding: utf-8 -*-
import argparse
import pandas as pd
from pathlib import Path

def main():
    parser = argparse.ArgumentParser(description="导出 MLST profiles (Oxford/Pasteur)")
    parser.add_argument("input_csv", help="输入 MLST_detailed_alleles.csv 文件路径")
    parser.add_argument("output_dir", help="输出目录")
    args = parser.parse_args()

    input_csv = Path(args.input_csv).resolve()
    outdir = Path(args.output_dir).resolve()
    outdir.mkdir(parents=True, exist_ok=True)

    out_ox = outdir / "MLST_ST_Ox.txt"
    out_pa = outdir / "MLST_ST_Pa.txt"

    # 读取输入
    df = pd.read_csv(input_csv)

    # 去掉 ST- 前缀
    if "Oxford_ST" in df.columns:
        df["Oxford_ST"] = df["Oxford_ST"].astype(str).str.replace("ST-", "", regex=False)
    if "Pasteur_ST" in df.columns:
        df["Pasteur_ST"] = df["Pasteur_ST"].astype(str).str.replace("ST-", "", regex=False)

    # 提取 Oxford
    df_ox = df.loc[:, [
        "Sample","Oxf_gltA","Oxf_gyrB","Oxf_gdhB",
        "Oxf_recA","Oxf_cpn60","Oxf_gpi","Oxf_rpoD"
    ]]
    df_ox.to_csv(out_ox, sep="\t", index=False, header=None)

    # 提取 Pasteur
    df_pa = df.loc[:, [
        "Sample","Pas_cpn60","Pas_fusA","Pas_gltA",
        "Pas_pyrG","Pas_recA","Pas_rplB","Pas_rpoB"
    ]]
    df_pa.to_csv(out_pa, sep="\t", index=False, header=None)

    print(f"[INFO] Oxford profiles 已导出到 {out_ox}")
    print(f"[INFO] Pasteur profiles 已导出到 {out_pa}")

if __name__ == "__main__":
    main()
