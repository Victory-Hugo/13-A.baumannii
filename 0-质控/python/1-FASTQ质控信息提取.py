import os
import sys
import csv
from bs4 import BeautifulSoup

def parse_fastqc_html(html_file):
    """解析 FastQC HTML 文件，返回关键参数字典"""
    with open(html_file, "r", encoding="utf-8") as f:
        soup = BeautifulSoup(f, "html.parser")

    result = {"sample": os.path.basename(html_file)}

    # 提取 summary
    summary = soup.find("div", {"class": "summary"})
    if summary:
        items = summary.find_all("li")
        for item in items:
            status = "PASS"
            if "WARNING" in item.text:
                status = "WARNING"
            elif "FAIL" in item.text:
                status = "FAIL"
            metric = item.text.strip()
            result[metric] = status

    # 提取基本统计表
    for table in soup.find_all("table"):
        rows = table.find_all("tr")
        for row in rows:
            cols = [c.get_text(strip=True) for c in row.find_all("td")]
            if len(cols) == 2:  # 一般是 Key - Value
                key, value = cols
                result[key] = value

    return result


def batch_parse_to_csv(html_files, output_csv):
    """批量解析 FastQC HTML 并输出为 CSV"""
    all_results = [parse_fastqc_html(f) for f in html_files]

    # 获取所有可能的列
    keys = set()
    for res in all_results:
        keys.update(res.keys())
    keys = ["sample"] + sorted(k for k in keys if k != "sample")

    # 写 CSV
    with open(output_csv, "w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=keys)
        writer.writeheader()
        writer.writerows(all_results)


if __name__ == "__main__":
    if len(sys.argv) < 3:
        print("用法: python fastqc_parser.py 输出文件.csv 输入1.html 输入2.html ...")
        sys.exit(1)

    output_csv = sys.argv[1]
    html_files = sys.argv[2:]

    batch_parse_to_csv(html_files, output_csv)
    print(f"结果已保存到 {output_csv}")
