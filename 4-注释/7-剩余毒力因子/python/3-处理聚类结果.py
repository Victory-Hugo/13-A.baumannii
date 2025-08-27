#!/usr/bin/env python3
"""
解析VSEARCH聚类结果，生成样本和基因的追踪表
输出聚类统计信息和详细的基因-样本对应关系
"""

import os
import sys
import pandas as pd
from pathlib import Path
from collections import defaultdict

def parse_uc_file(uc_file):
    """
    解析VSEARCH的.uc输出文件
    
    .uc文件格式:
    H: Hit (cluster member)
    S: Centroid (cluster seed)
    C: Cluster record
    
    字段: Type, Cluster, Size, %Identity, Strand, QueryStart, SeedStart, Alignment, Query, Target
    """
    clusters = defaultdict(list)
    cluster_info = {}
    
    with open(uc_file, 'r') as f:
        for line in f:
            if line.startswith('#'):
                continue
            
            fields = line.strip().split('\t')
            record_type = fields[0]
            
            if record_type == 'S':  # Centroid/Seed
                cluster_id = int(fields[1]) # 第二列是聚类编号
                query_id = fields[8] # 第九列是序列ID
                clusters[cluster_id].append({
                    'sequence_id': query_id,
                    'role': 'centroid',
                    'identity': 100.0
                })
                cluster_info[cluster_id] = {
                    'centroid': query_id,
                    'size': 1
                }
            
            elif record_type == 'H':  # Hit/Member
                cluster_id = int(fields[1])
                identity = float(fields[3])
                query_id = fields[8] # hit 序列ID
                target_id = fields[9] # 对应的 seed 序列
                
                clusters[cluster_id].append({
                    'sequence_id': query_id,
                    'role': 'member',
                    'identity': identity,
                    'centroid': target_id
                })
                cluster_info[cluster_id]['size'] += 1
            
            elif record_type == 'C':  # Cluster summary
                cluster_id = int(fields[1])
                size = int(fields[2])
                centroid = fields[8]
                
                if cluster_id not in cluster_info:
                    cluster_info[cluster_id] = {
                        'centroid': centroid,
                        'size': size
                    }
    
    return clusters, cluster_info

def extract_sample_and_gene_info(sequence_id):
    """
    从序列ID中提取样本信息和基因信息
    输入格式: SAMPLE_ERR1946991|INDDICEB_00001 hypothetical protein
    """
    if '|' in sequence_id:
        sample_part, gene_part = sequence_id.split('|', 1)
        sample_id = sample_part.replace('SAMPLE_', '')
        
        # 分离基因ID和描述
        gene_parts = gene_part.split(' ', 1)
        gene_id = gene_parts[0]
        gene_description = gene_parts[1] if len(gene_parts) > 1 else ""
        
        return sample_id, gene_id, gene_description
    else:
        # 如果没有样本信息，假设整个就是基因ID
        return "Unknown", sequence_id, ""

def generate_tracking_table(clusters, output_dir):
    """生成基因-样本追踪表"""
    tracking_data = []
    
    for cluster_id, members in clusters.items():
        for member in members:
            sequence_id = member['sequence_id']
            sample_id, gene_id, gene_description = extract_sample_and_gene_info(sequence_id)
            
            tracking_data.append({
                'cluster_id': cluster_id,
                'sample_id': sample_id,
                'gene_id': gene_id,
                'gene_description': gene_description,
                'full_sequence_id': sequence_id,
                'role_in_cluster': member['role'],
                'identity_to_centroid': member['identity']
            })
    
    # 转换为DataFrame并保存
    df = pd.DataFrame(tracking_data)
    tracking_file = os.path.join(output_dir, 'gene_sample_tracking.tsv')
    df.to_csv(tracking_file, sep='\t', index=False)
    
    print(f"基因-样本追踪表已保存: {tracking_file}")
    return df

def generate_cluster_statistics(clusters, cluster_info, output_dir):
    """生成聚类统计信息"""
    stats_data = []
    
    for cluster_id, members in clusters.items():
        # 统计每个样本在该聚类中的基因数
        sample_counts = defaultdict(int)
        for member in members:
            sample_id, _, _ = extract_sample_and_gene_info(member['sequence_id'])
            sample_counts[sample_id] += 1
        
        # 计算身份认同度统计
        identities = [m['identity'] for m in members if m['role'] == 'member']
        min_identity = min(identities) if identities else 100.0
        max_identity = max(identities) if identities else 100.0
        avg_identity = sum(identities) / len(identities) if identities else 100.0
        
        stats_data.append({
            'cluster_id': cluster_id,
            'cluster_size': len(members),
            'centroid_sequence': cluster_info[cluster_id]['centroid'],
            'samples_involved': len(sample_counts),
            'sample_distribution': ';'.join([f"{k}:{v}" for k, v in sample_counts.items()]),
            'min_identity': round(min_identity, 2),
            'max_identity': round(max_identity, 2),
            'avg_identity': round(avg_identity, 2)
        })
    
    # 转换为DataFrame并保存
    df_stats = pd.DataFrame(stats_data)
    stats_file = os.path.join(output_dir, 'cluster_statistics.tsv')
    df_stats.to_csv(stats_file, sep='\t', index=False)
    
    print(f"聚类统计信息已保存: {stats_file}")
    return df_stats

def print_summary(clusters, df_tracking):
    """打印总结信息"""
    total_clusters = len(clusters)
    total_genes = len(df_tracking)
    samples = df_tracking['sample_id'].unique()
    
    print(f"\n=== 聚类结果总结 ===")
    print(f"总聚类数: {total_clusters}")
    print(f"总基因数: {total_genes}")
    print(f"涉及样本数: {len(samples)}")
    print(f"样本列表: {', '.join(samples)}")
    
    # 聚类大小分布
    cluster_sizes = [len(members) for members in clusters.values()]
    print(f"\n聚类大小分布:")
    print(f"  单基因聚类 (size=1): {sum(1 for s in cluster_sizes if s == 1)}")
    print(f"  小聚类 (size=2-5): {sum(1 for s in cluster_sizes if 2 <= s <= 5)}")
    print(f"  中聚类 (size=6-10): {sum(1 for s in cluster_sizes if 6 <= s <= 10)}")
    print(f"  大聚类 (size>10): {sum(1 for s in cluster_sizes if s > 10)}")
    print(f"  最大聚类大小: {max(cluster_sizes)}")

def main():
    if len(sys.argv) != 3:
        print("用法: python3 parse_clustering_results.py <uc_file> <output_dir>")
        print("示例: python3 parse_clustering_results.py clustering_results.uc /path/to/output")
        sys.exit(1)
    
    uc_file = sys.argv[1]
    output_dir = sys.argv[2]
    
    # 检查输入文件
    if not os.path.isfile(uc_file):
        print(f"错误: UC文件 {uc_file} 不存在")
        sys.exit(1)
    
    # 创建输出目录
    os.makedirs(output_dir, exist_ok=True)
    
    print(f"解析VSEARCH聚类结果...")
    print(f"输入文件: {uc_file}")
    print(f"输出目录: {output_dir}")
    
    # 解析UC文件
    clusters, cluster_info = parse_uc_file(uc_file)
    
    # 生成追踪表
    df_tracking = generate_tracking_table(clusters, output_dir)
    
    # 生成统计信息
    df_stats = generate_cluster_statistics(clusters, cluster_info, output_dir)
    
    # 打印总结
    print_summary(clusters, df_tracking)

if __name__ == "__main__":
    main()
