#!/usr/bin/env python3
"""
清理FAA文件中的序列头，移除可能导致spacedust createsetdb失败的特殊字符
"""

import os
import re
import sys
from pathlib import Path

def clean_header(header):
    """清理序列头，只保留第一个标识符部分"""
    # 移除>符号
    header = header.lstrip('>')
    # 只保留第一个空格之前的部分
    header = header.split()[0] if header.split() else header
    # 移除可能有问题的字符，只保留字母数字和下划线
    header = re.sub(r'[^a-zA-Z0-9_]', '_', header)
    return '>' + header

def clean_faa_file(input_file, output_file):
    """清理单个FAA文件"""
    print(f"清理文件: {input_file} -> {output_file}")
    
    with open(input_file, 'r') as infile, open(output_file, 'w') as outfile:
        for line in infile:
            if line.startswith('>'):
                # 清理序列头
                cleaned_header = clean_header(line.strip())
                outfile.write(cleaned_header + '\n')
            else:
                # 保持序列行不变
                outfile.write(line)

def main():
    if len(sys.argv) != 3:
        print("用法: python3 clean_faa_headers.py <输入目录> <输出目录>")
        sys.exit(1)
    
    input_dir = Path(sys.argv[1])
    output_dir = Path(sys.argv[2])
    
    if not input_dir.exists():
        print(f"错误: 输入目录不存在: {input_dir}")
        sys.exit(1)
    
    # 创建输出目录
    output_dir.mkdir(parents=True, exist_ok=True)
    
    # 查找所有FAA文件
    faa_files = list(input_dir.glob("*.faa"))
    
    if not faa_files:
        print(f"警告: 在目录 {input_dir} 中未找到.faa文件")
        return
    
    print(f"找到 {len(faa_files)} 个FAA文件")
    
    for faa_file in faa_files:
        output_file = output_dir / faa_file.name
        clean_faa_file(faa_file, output_file)
    
    print("所有文件清理完成")

if __name__ == "__main__":
    main()