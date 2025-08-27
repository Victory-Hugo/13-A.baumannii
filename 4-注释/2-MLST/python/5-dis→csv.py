import numpy as np
import pandas as pd
import os, sys

def dist_to_csv(file_path: str):
    # 先跳过第一行
    with open(file_path) as f:
        n = int(f.readline().strip())
    # 第二列开始是矩阵
    data = np.loadtxt(file_path, skiprows=1, usecols=range(1, n+1))
    samples = np.loadtxt(file_path, skiprows=1, usecols=0, dtype=str)

    df = pd.DataFrame(data, index=samples, columns=samples)
    output_path = os.path.splitext(file_path)[0] + ".csv"
    df.to_csv(output_path)
    print(f"✅ 转换完成: {output_path}")


if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("用法: python dist2csv.py <输入文件路径>")
        sys.exit(1)
    dist_to_csv(sys.argv[1])
