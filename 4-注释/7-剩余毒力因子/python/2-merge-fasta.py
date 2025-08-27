#!/usr/bin/env python3
"""
合并多个样本的FASTA文件，并在序列ID中添加样本信息
保留原始基因ID和样本ID用于后期追踪
"""

import os
import sys
from pathlib import Path

def extract_sample_id(filename):
    """从文件名中提取样本ID"""
    # 假设文件名格式为 ERR1946991.Remain.ffn
    sample_id = filename.split('.')[0]
    return sample_id

def merge_fasta_files(input_dir, output_file):
    """
    合并所有.ffn文件，并在序列ID中添加样本信息
    
    Args:
        input_dir: 输入目录路径
        output_file: 输出文件路径
    """
    input_path = Path(input_dir)
    
    # 查找所有.ffn文件
    fasta_files = list(input_path.glob("*.ffn"))
    
    if not fasta_files:
        print(f"在 {input_dir} 中未找到.ffn文件")
        return
    
    total_sequences = 0
    sample_counts = {}
    
    with open(output_file, 'w') as outf:
        for fasta_file in sorted(fasta_files):
            sample_id = extract_sample_id(fasta_file.name)
            sample_counts[sample_id] = 0
            
            print(f"处理文件: {fasta_file.name} (样本ID: {sample_id})")
            
            with open(fasta_file, 'r') as inf:
                for line in inf:
                    line = line.strip()
                    if line.startswith('>'):
                        # 修改序列头，添加样本信息
                        # 原格式: >INDDICEB_00001 hypothetical protein
                        # 新格式: >SAMPLE_ERR1946991|INDDICEB_00001 hypothetical protein
                        original_header = line[1:]  # 去掉'>'
                        new_header = f">SAMPLE_{sample_id}|{original_header}"
                        outf.write(new_header + '\n')
                        sample_counts[sample_id] += 1
                        total_sequences += 1
                    else:
                        outf.write(line + '\n')
    
    print(f"\n合并完成！")
    print(f"输出文件: {output_file}")
    print(f"总序列数: {total_sequences}")
    print("各样本序列数:")
    for sample, count in sample_counts.items():
        print(f"  {sample}: {count}")

def main():
    if len(sys.argv) != 3:
        print("用法: python3 merge_fasta_with_sample_info.py <input_dir> <output_file>")
        print("示例: python3 merge_fasta_with_sample_info.py /path/to/input /path/to/output.fasta")
        sys.exit(1)
    
    input_dir = sys.argv[1]
    output_file = sys.argv[2]
    
    # 检查输入目录
    if not os.path.isdir(input_dir):
        print(f"错误: 输入目录 {input_dir} 不存在")
        sys.exit(1)
    
    # 创建输出目录
    os.makedirs(os.path.dirname(output_file), exist_ok=True)
    
    merge_fasta_files(input_dir, output_file)

if __name__ == "__main__":
    main()
