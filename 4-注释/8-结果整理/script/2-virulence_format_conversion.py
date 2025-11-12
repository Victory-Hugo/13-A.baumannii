#!/usr/bin/env python3
"""
毒力因子注释结果格式转换工具
将毒力因子合并文件转换成多种统计格式，便于下游分析与可视化。

用法：
    python3 2-virulence_format_conversion.py <input_csv> <output_dir> [是否输出具体文件]

第三个参数可选（默认"是"）：
    - "是/yes" 输出全部格式
    - "否/no" 仅输出样本总数表

输出：
    0-virulence_sample_totals.csv      # 样本毒力因子总数
    1-virulence_presence_absence.csv   # 样本 × 毒力因子 presence/absence 矩阵
    2-virulence_tidy_long.csv          # tidy 长表
    3-virulence_sample_summary.csv     # 样本层面统计
    4-virulence_gene_cooccurrence.csv  # 因子共现矩阵
    5-virulence_gene_summary.csv       # 因子出现频率
    README_virulence_summary.txt       # 输出说明
"""
import io
from collections import Counter
from pathlib import Path
import sys

import pandas as pd

DEFAULT_FULL_OUTPUT_FLAG = "是"
FULL_OUTPUT_TRUE = {"是", "yes", "y", "true", "1", "all", "full"}
FULL_OUTPUT_FALSE = {"否", "no", "n", "false", "0", "none"}

ENTITY_NAME = "毒力因子"
PREFIX = "virulence"


def load_table(csv_path):
    """加载CSV，包含容错读取。"""
    csv_path = Path(csv_path)
    if not csv_path.exists():
        raise FileNotFoundError(f"找不到输入文件：{csv_path}")
    try:
        df = pd.read_csv(csv_path)
        print(f"✓ 加载数据：{len(df)} 行")
        return df
    except pd.errors.ParserError as exc:
        print(f"⚠️ CSV解析错误: {exc}")
    try:
        df = pd.read_csv(
            csv_path,
            quoting=1,
            skipinitialspace=True,
            on_bad_lines="skip",
            low_memory=False,
        )
        print(f"✓ 使用容错模式加载数据：{len(df)} 行")
        return df
    except Exception as exc:
        print(f"⚠️ 容错模式仍失败：{exc}")
        return load_table_line_by_line(csv_path)


def load_table_line_by_line(csv_path):
    """逐行清理CSV，最后的兜底方案。"""
    print("📖 逐行清理 CSV ...")
    with open(csv_path, "r", encoding="utf-8", errors="ignore") as handle:
        lines = [line for line in handle.read().splitlines() if line.strip()]
    if not lines:
        return pd.DataFrame(columns=["filename", "qseqid", "sseqid"])
    header = lines[0]
    expected_cols = len(header.split(","))
    cleaned = [header]
    buffer = ""
    for line in lines[1:]:
        buffer = f"{buffer} {line.strip()}".strip() if buffer else line.strip()
        if buffer.count(",") >= expected_cols - 1:
            cleaned.append(buffer)
            buffer = ""
    if buffer:
        cleaned.append(buffer)
    try:
        return pd.read_csv(io.StringIO("\n".join(cleaned)))
    except Exception:
        columns = header.split(",")
        return pd.DataFrame(columns=columns)


def parse_subject_id(value):
    """从sseqid字段拆分出因子ID与参考信息。"""
    if pd.isna(value):
        return "", ""
    text = str(value).strip()
    if not text:
        return "", ""
    reference = ""
    gene_id = text
    if "(" in text and text.endswith(")"):
        gene_id = text.split("(", 1)[0]
        reference = text[text.find("(") + 1 : -1]
    elif "|" in text:
        parts = text.split("|")
        gene_id = parts[-1]
        reference = "|".join(parts[:-1])
    return gene_id.strip(), reference.strip()


def prepare_dataframe(df):
    """规范化字段，添加辅助列。"""
    required_cols = {"filename", "qseqid", "sseqid"}
    missing = required_cols - set(df.columns)
    if missing:
        raise ValueError(f"输入文件缺少必要列：{', '.join(sorted(missing))}")
    normalized = df.copy()
    normalized["Sample"] = normalized["filename"].astype(str).str.strip()
    normalized["Filename"] = normalized["Sample"]
    normalized["Query_ID"] = normalized["qseqid"].astype(str).str.strip()
    normalized["Raw_Subject"] = normalized["sseqid"].astype(str).str.strip()
    parsed = normalized["Raw_Subject"].map(parse_subject_id)
    normalized["Subject_ID"] = parsed.map(lambda pair: pair[0])
    normalized["Subject_Reference"] = parsed.map(lambda pair: pair[1])
    normalized["Subject_ID"] = normalized["Subject_ID"].fillna("").str.strip()
    normalized["Subject_Reference"] = normalized["Subject_Reference"].fillna("").str.strip()
    normalized["Subject_Category"] = ENTITY_NAME
    return normalized


def parse_full_output_flag(value):
    if value is None:
        return True
    normalized = str(value).strip().lower()
    if not normalized:
        return True
    if normalized in FULL_OUTPUT_TRUE:
        return True
    if normalized in FULL_OUTPUT_FALSE:
        return False
    print(f"⚠️ 未能识别参数“{value}”，默认输出全部文件。")
    return True


def export_sample_total_counts(df, output_dir):
    """输出样本毒力因子总数"""
    valid_df = df[df["Sample"].astype(str).str.strip() != ""]
    totals = (
        valid_df.groupby("Sample")
        .size()
        .reset_index(name="Total_Virulence_Factors")
        .sort_values("Sample")
    )
    output_file = output_dir / f"0-{PREFIX}_sample_totals.csv"
    totals.to_csv(output_file, index=False)
    print("\n=== 样本毒力因子总数 ===")
    print(f"✓ 输出：{output_file}")
    if not totals.empty:
        print(totals.to_string(index=False))
    else:
        print("  （无有效样本）")
    return totals, output_file


def format_top_hits(values, top_n=5):
    counts = Counter(v for v in values if isinstance(v, str) and v.strip())
    if not counts:
        return ""
    return "; ".join(f"{gene}:{count}" for gene, count in counts.most_common(top_n))


def export_presence_absence(df, output_dir):
    subset = df[["Sample", "Subject_ID"]].dropna()
    subset = subset[subset["Subject_ID"].str.len() > 0].drop_duplicates()
    if subset.empty:
        print("⚠️ 缺少有效的因子信息，跳过 presence/absence 矩阵。")
        return None, None
    matrix = pd.crosstab(subset["Sample"], subset["Subject_ID"]).astype(int)
    output_file = output_dir / f"1-{PREFIX}_presence_absence.csv"
    matrix.to_csv(output_file)
    print(f"✓ 输出：{output_file}")
    print(f"  维度：{matrix.shape[0]} 样本 × {matrix.shape[1]} 因子")
    return matrix, output_file


def export_long_format(df, output_dir):
    columns = [
        "Sample",
        "Filename",
        "Query_ID",
        "Subject_ID",
        "Subject_Reference",
        "Raw_Subject",
        "Subject_Category",
    ]
    long_df = df[columns].copy()
    long_df.rename(
        columns={
            "Query_ID": "Query_locus",
            "Subject_ID": "Virulence_ID",
            "Subject_Reference": "Reference",
            "Raw_Subject": "Original_sseqid",
        },
        inplace=True,
    )
    long_df.sort_values(["Sample", "Virulence_ID", "Query_locus"], inplace=True)
    output_file = output_dir / f"2-{PREFIX}_tidy_long.csv"
    long_df.to_csv(output_file, index=False)
    print(f"✓ 输出：{output_file}")
    print(f"  共 {len(long_df)} 条记录")
    return long_df, output_file


def export_sample_summary(df, output_dir):
    summary = (
        df.groupby("Sample")
        .agg(
            Total_hits=("Subject_ID", "count"),
            Unique_virulence=("Subject_ID", pd.Series.nunique),
            Unique_queries=("Query_ID", pd.Series.nunique),
        )
        .reset_index()
    )
    summary["Top_virulence"] = summary["Sample"].map(
        lambda sample: format_top_hits(df[df["Sample"] == sample]["Subject_ID"])
    )
    output_file = output_dir / f"3-{PREFIX}_sample_summary.csv"
    summary.to_csv(output_file, index=False)
    print(f"✓ 输出：{output_file}")
    return summary, output_file


def first_non_empty(values):
    for value in values:
        if isinstance(value, str) and value.strip():
            return value.strip()
    return ""


def export_gene_cooccurrence(df, output_dir):
    gene_df = df.dropna(subset=["Subject_ID"])
    gene_df = gene_df[gene_df["Subject_ID"].str.len() > 0]
    genes = sorted(gene_df["Subject_ID"].unique())
    if not genes:
        print("⚠️ 因子列表为空，跳过共现矩阵。")
        return None, None
    matrix = pd.DataFrame(0, index=genes, columns=genes, dtype=int)
    for _, group in gene_df.groupby("Sample"):
        sample_genes = sorted(group["Subject_ID"].unique())
        for i, gene_a in enumerate(sample_genes):
            for gene_b in sample_genes[i:]:
                matrix.loc[gene_a, gene_b] += 1
                if gene_a != gene_b:
                    matrix.loc[gene_b, gene_a] += 1
    output_file = output_dir / f"4-{PREFIX}_gene_cooccurrence.csv"
    matrix.to_csv(output_file)
    print(f"✓ 输出：{output_file}")
    return matrix, output_file


def export_gene_summary(df, output_dir):
    gene_df = df.dropna(subset=["Subject_ID"])
    gene_df = gene_df[gene_df["Subject_ID"].str.len() > 0]
    if gene_df.empty:
        print("⚠️ 没有可汇总的毒力因子，跳过 gene summary。")
        return None, None
    summary = (
        gene_df.groupby("Subject_ID")
        .agg(
            Total_hits=("Sample", "count"),
            Unique_samples=("Sample", pd.Series.nunique),
            Example_queries=("Query_ID", lambda x: "; ".join(x.dropna().unique()[:5])),
            Reference=("Subject_Reference", first_non_empty),
        )
        .reset_index()
        .sort_values("Total_hits", ascending=False)
    )
    output_file = output_dir / f"5-{PREFIX}_gene_summary.csv"
    summary.to_csv(output_file, index=False)
    print(f"✓ 输出：{output_file}")
    return summary, output_file


def write_report(output_dir, df, outputs):
    sample_count = df["Sample"].nunique()
    gene_count = df["Subject_ID"].replace("", pd.NA).dropna().nunique()
    total_hits = len(df)
    lines = "\n".join(f"  - {label}: {path}" for label, path in outputs if path)
    report = f"""
毒力因子数据整理完成！

基本统计：
  - 样本数：{sample_count}
  - 非空毒力因子数：{gene_count}
  - 命中记录：{total_hits}

生成的文件：
{lines or '  - （无有效输出，检查输入数据）'}

建议流程：
  1. 使用 3-virulence_sample_summary.csv 快速了解每个基因组的毒力负载。
  2. 使用 1-virulence_presence_absence.csv 进行聚类或热力图分析。
  3. 使用 4-virulence_gene_cooccurrence.csv / 6-virulence_network.json 探索因子共现关系。
"""
    report_file = output_dir / "README_virulence_summary.txt"
    with open(report_file, "w", encoding="utf-8") as handle:
        handle.write(report.strip() + "\n")
    print(f"📄 摘要：{report_file}")
    return report_file


def main():
    if len(sys.argv) not in (3, 4):
        print(__doc__)
        sys.exit(1)
    csv_file = Path(sys.argv[1])
    output_dir = Path(sys.argv[2])
    flag_value = sys.argv[3] if len(sys.argv) == 4 else DEFAULT_FULL_OUTPUT_FLAG
    full_output = parse_full_output_flag(flag_value)
    output_dir.mkdir(parents=True, exist_ok=True)
    raw_df = load_table(csv_file)
    normalized_df = prepare_dataframe(raw_df)
    outputs = []

    _, totals_path = export_sample_total_counts(normalized_df, output_dir)
    outputs.append(("样本总数统计", totals_path))

    if not full_output:
        print("ℹ️ 根据参数“是否输出具体文件=否”，仅输出样本总数文件。")
        return

    _, path = export_presence_absence(normalized_df, output_dir)
    if path:
        outputs.append(("presence/absence 矩阵", path))
    _, path = export_long_format(normalized_df, output_dir)
    if path:
        outputs.append(("tidy 长表", path))
    _, path = export_sample_summary(normalized_df, output_dir)
    if path:
        outputs.append(("样本汇总", path))
    _, path = export_gene_cooccurrence(normalized_df, output_dir)
    if path:
        outputs.append(("因子共现矩阵", path))
    _, path = export_gene_summary(normalized_df, output_dir)
    if path:
        outputs.append(("因子频次汇总", path))
    report_path = write_report(output_dir, normalized_df, outputs)
    outputs.append(("README", report_path))
    print("\n✅ 毒力因子数据格式转换完成！")


if __name__ == "__main__":
    main()
