#!/usr/bin/env python3
import argparse
import os
import sys


def _read_quality_summary(path):
    data = {}
    if not os.path.isfile(path):
        return data
    with open(path, "r", encoding="utf-8") as fh:
        header = fh.readline().strip().split("\t")
        for line in fh:
            line = line.strip()
            if not line:
                continue
            cols = line.split("\t")
            row = dict(zip(header, cols))
            sample = row.get("sample")
            if sample:
                data[sample] = row
    return data


def _read_damage_freq(path):
    if not os.path.isfile(path):
        return {}
    freq = {}
    with open(path, "r", encoding="utf-8") as fh:
        _ = fh.readline()
        for line in fh:
            line = line.strip()
            if not line:
                continue
            pos, val = line.split("\t", 1)
            freq[pos] = val
    return freq


def run(quality_dir, output_dir=None, mode="two", output_prefix="quality_merged"):
    if output_dir is None:
        output_dir = quality_dir

    quality_summary = os.path.join(quality_dir, "quality_summary.tsv")
    damage_root = os.path.join(quality_dir, "damage")

    os.makedirs(output_dir, exist_ok=True)

    quality_data = _read_quality_summary(quality_summary)

    samples = set(quality_data.keys())
    damage_data = {}

    if os.path.isdir(damage_root):
        for name in sorted(os.listdir(damage_root)):
            sample_dir = os.path.join(damage_root, name)
            if not os.path.isdir(sample_dir):
                continue
            freq_5p = _read_damage_freq(os.path.join(sample_dir, "5pCtoT_freq.txt"))
            freq_3p = _read_damage_freq(os.path.join(sample_dir, "3pGtoA_freq.txt"))
            if not freq_5p and not freq_3p:
                continue
            damage_data[name] = {"5p": freq_5p, "3p": freq_3p}
            samples.add(name)

    samples = sorted(samples)

    summary_out = os.path.join(output_dir, f"{output_prefix}.tsv")
    with open(summary_out, "w", encoding="utf-8") as out:
        out.write("sample\tmapped_percent\tmean_depth\t5pCtoT_pos1\t3pGtoA_pos1\n")
        for sample in samples:
            row = quality_data.get(sample, {})
            mapped = row.get("mapped_percent", "NA")
            depth = row.get("mean_depth", "NA")
            freq_5p = damage_data.get(sample, {}).get("5p", {})
            freq_3p = damage_data.get(sample, {}).get("3p", {})
            c2t = freq_5p.get("1", "NA")
            g2a = freq_3p.get("1", "NA")
            out.write(f"{sample}\t{mapped}\t{depth}\t{c2t}\t{g2a}\n")

    profile_out = None
    if mode == "two":
        profile_out = os.path.join(output_dir, f"{output_prefix}_damage_profile.tsv")
        with open(profile_out, "w", encoding="utf-8") as out:
            out.write("sample\tpos\t5pCtoT\t3pGtoA\n")
            for sample in samples:
                freq_5p = damage_data.get(sample, {}).get("5p", {})
                freq_3p = damage_data.get(sample, {}).get("3p", {})
                positions = sorted(set(freq_5p.keys()) | set(freq_3p.keys()), key=lambda x: int(x))
                for pos in positions:
                    c2t = freq_5p.get(pos, "NA")
                    g2a = freq_3p.get(pos, "NA")
                    out.write(f"{sample}\t{pos}\t{c2t}\t{g2a}\n")

    return summary_out, profile_out


def main():
    parser = argparse.ArgumentParser(
        description="Merge quality summary and mapDamage outputs."
    )
    parser.add_argument(
        "-q", "--quality-dir", required=True, help="quality output directory"
    )
    parser.add_argument(
        "-o", "--output-dir", default=None, help="output directory (default: quality-dir)"
    )
    parser.add_argument(
        "-m",
        "--mode",
        choices=["one", "two"],
        default="two",
        help="output one or two tables",
    )
    parser.add_argument(
        "-p", "--output-prefix", default="quality_merged", help="output file prefix"
    )
    args = parser.parse_args()

    if not os.path.isdir(args.quality_dir):
        sys.exit(f"Error: quality dir not found: {args.quality_dir}")

    run(
        quality_dir=args.quality_dir,
        output_dir=args.output_dir,
        mode=args.mode,
        output_prefix=args.output_prefix,
    )


if __name__ == "__main__":
    main()
