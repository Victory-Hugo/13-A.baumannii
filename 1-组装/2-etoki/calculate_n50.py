#!/usr/bin/env python3
"""
计算基因组组装的N50统计信息
"""

def calculate_n50_stats(fasta_file):
    """计算N50、N90等统计信息"""
    sequences = []
    current_seq = ""
    
    with open(fasta_file, 'r') as f:
        for line in f:
            line = line.strip()
            if line.startswith('>'):
                if current_seq:
                    sequences.append(len(current_seq))
                current_seq = ""
            else:
                current_seq += line
        
        # 添加最后一个序列
        if current_seq:
            sequences.append(len(current_seq))
    
    # 按长度降序排序
    sequences.sort(reverse=True)
    
    total_length = sum(sequences)
    num_contigs = len(sequences)
    
    # 计算N50
    cumulative_length = 0
    n50 = 0
    n90 = 0
    
    for length in sequences:
        cumulative_length += length
        if cumulative_length >= total_length * 0.5 and n50 == 0:
            n50 = length
        if cumulative_length >= total_length * 0.9 and n90 == 0:
            n90 = length
            break
    
    print(f"=== 鲍曼不动杆菌 ERR197551 组装统计 ===")
    print(f"Contigs数量: {num_contigs:,}")
    print(f"总组装长度: {total_length:,} bp ({total_length/1e6:.2f} Mb)")
    print(f"最长contig: {sequences[0]:,} bp")
    print(f"N50: {n50:,} bp")
    print(f"N90: {n90:,} bp")
    print(f"平均contig长度: {total_length/num_contigs:.0f} bp")
    
    # 计算大于不同长度阈值的contigs数量
    thresholds = [1000, 5000, 10000, 50000, 100000]
    print(f"\n=== 长度分布 ===")
    for threshold in thresholds:
        count = sum(1 for length in sequences if length >= threshold)
        print(f"≥{threshold:,} bp的contigs: {count}")

if __name__ == "__main__":
    calculate_n50_stats("ERR197551_assembly/spades.fasta")
