#!/usr/bin/env python3
import argparse
import os
import sys
from statistics import mean

def read_freq(path):
    rows = []
    with open(path, "r", encoding="utf-8") as f:
        header = f.readline()
        if not header:
            raise ValueError(f"empty file: {path}")
        for line in f:
            line = line.strip()
            if not line:
                continue
            parts = line.split("\t")
            if len(parts) != 2:
                raise ValueError(f"bad line in {path}: {line}")
            pos = int(parts[0])
            val = float(parts[1])
            rows.append((pos, val))
    if not rows:
        raise ValueError(f"no data rows: {path}")
    return rows

def summarize(rows, label):
    rows = sorted(rows, key=lambda x: x[0])
    vals = [v for _, v in rows]
    pos1 = vals[0]
    first5 = mean(vals[:5]) if len(vals) >= 5 else mean(vals)
    tail = mean(vals[-10:]) if len(vals) >= 10 else mean(vals)
    ratio = first5 / tail if tail > 0 else float("inf")
    return {
        "label": label,
        "pos1": pos1,
        "first5": first5,
        "tail": tail,
        "ratio": ratio,
        "n": len(vals),
    }

def verdict(c2t, g2a):
    # Heuristic: typical aDNA shows elevated terminal damage vs interior.
    flags = []
    if c2t["ratio"] >= 1.5 and c2t["pos1"] >= 0.05:
        flags.append("5p_CtoT_elevated")
    if g2a["ratio"] >= 1.5 and g2a["pos1"] >= 0.05:
        flags.append("3p_GtoA_elevated")

    if len(flags) == 2:
        return "consistent with typical aDNA terminal damage", flags
    if len(flags) == 1:
        return "partial aDNA signal (one end elevated)", flags
    return "no clear aDNA terminal damage signal", flags

def main():
    parser = argparse.ArgumentParser(description="Check aDNA terminal damage signal from mapDamage outputs.")
    parser.add_argument(
        "results_dir",
        nargs="?",
        default="/mnt/d/6-HPgnomAD-Origin-data/5-NCBI/2-Ancient-DNA/quality/damage/results_ancient_top3.sorted",
        help="mapDamage results directory",
    )
    parser.add_argument(
        "--out",
        default=None,
        help="write report to file (default: <results_dir>/aDNA_report.txt)",
    )
    args = parser.parse_args()

    c2t_path = os.path.join(args.results_dir, "5pCtoT_freq.txt")
    g2a_path = os.path.join(args.results_dir, "3pGtoA_freq.txt")

    if not os.path.exists(c2t_path):
        print(f"missing file: {c2t_path}", file=sys.stderr)
        sys.exit(1)
    if not os.path.exists(g2a_path):
        print(f"missing file: {g2a_path}", file=sys.stderr)
        sys.exit(1)

    c2t = summarize(read_freq(c2t_path), "5pCtoT")
    g2a = summarize(read_freq(g2a_path), "3pGtoA")

    verdict_text, flags = verdict(c2t, g2a)
    out_path = args.out or os.path.join(args.results_dir, "aDNA_report.txt")

    report = []
    report.append("aDNA terminal damage report")
    report.append(f"results_dir: {args.results_dir}")
    report.append("")
    report.append("5' C->T")
    report.append(f"  n_positions: {c2t['n']}")
    report.append(f"  pos1: {c2t['pos1']:.4f}")
    report.append(f"  mean_first5: {c2t['first5']:.4f}")
    report.append(f"  mean_tail: {c2t['tail']:.4f}")
    report.append(f"  first5/tail: {c2t['ratio']:.2f}")
    report.append("")
    report.append("3' G->A")
    report.append(f"  n_positions: {g2a['n']}")
    report.append(f"  pos1: {g2a['pos1']:.4f}")
    report.append(f"  mean_first5: {g2a['first5']:.4f}")
    report.append(f"  mean_tail: {g2a['tail']:.4f}")
    report.append(f"  first5/tail: {g2a['ratio']:.2f}")
    report.append("")
    report.append(f"verdict: {verdict_text}")
    if flags:
        report.append(f"flags: {', '.join(flags)}")

    text = "\n".join(report) + "\n"

    with open(out_path, "w", encoding="utf-8") as f:
        f.write(text)

    print(text, end="")

if __name__ == "__main__":
    main()
