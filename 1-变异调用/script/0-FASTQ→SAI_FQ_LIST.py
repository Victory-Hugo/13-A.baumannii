#!/usr/bin/env python3
import argparse
import os
import sys


def strip_ext(path):
    name = os.path.basename(path)
    for ext in (".fastq.gz", ".fq.gz", ".fastq", ".fq"):
        if name.endswith(ext):
            return name[: -len(ext)]
    return os.path.splitext(name)[0]


def sample_prefix(name):
    if name.endswith("_1"):
        return name[:-2]
    if name.endswith("_2"):
        return name[:-2]
    return name


def main():
    parser = argparse.ArgumentParser(
        description="Build SAI_FQ_LIST from FASTQ list and SAI output dir."
    )
    parser.add_argument("-i", "--input", required=True, help="FASTQ list txt")
    parser.add_argument("-s", "--sai-dir", required=True, help="SAI output dir")
    parser.add_argument("-o", "--output", required=True, help="SAI_FQ_LIST output")
    args = parser.parse_args()

    if not os.path.isfile(args.input):
        sys.exit(f"Error: input list not found: {args.input}")
    if not os.path.isdir(args.sai_dir):
        sys.exit(f"Error: SAI output dir not found: {args.sai_dir}")

    pairs = {}
    with open(args.input, "r", encoding="utf-8") as fh:
        for raw in fh:
            line = raw.strip()
            if not line:
                continue
            fq = line
            base = strip_ext(fq)
            prefix = sample_prefix(base)
            if base.endswith("_1"):
                pairs.setdefault(prefix, {})["fq1"] = fq
            elif base.endswith("_2"):
                pairs.setdefault(prefix, {})["fq2"] = fq
            else:
                sys.exit(f"Error: FASTQ missing _1/_2 suffix: {fq}")

    missing = [k for k, v in pairs.items() if "fq1" not in v or "fq2" not in v]
    if missing:
        sys.stderr.write(
            "Warning: missing pair for: " + ", ".join(sorted(missing)) + "\n"
        )

    os.makedirs(os.path.dirname(args.output), exist_ok=True)
    written = 0
    with open(args.output, "w", encoding="utf-8") as out:
        for prefix in sorted(pairs.keys()):
            if prefix in missing:
                continue
            fq1 = pairs[prefix]["fq1"]
            fq2 = pairs[prefix]["fq2"]
            sai1 = os.path.join(args.sai_dir, strip_ext(fq1) + ".sai")
            sai2 = os.path.join(args.sai_dir, strip_ext(fq2) + ".sai")
            out.write(f"{sai1}\t{sai2}\t{fq1}\t{fq2}\n")
            written += 1

    if written == 0:
        sys.exit("Error: no valid pairs found")


if __name__ == "__main__":
    main()
