#!/usr/bin/env python3
"""
生物杀灭抵抗结果格式转换工具
将生物杀灭抵抗数据整理为多种格式用于不同的数据分析

功能：
1. CSV → 宽表格式（样本×抵抗基因）
2. CSV → 长表格式（规范化）
3. CSV → 抵抗机制统计表
4. CSV → 基因共现矩阵
5. CSV → JSON格式（便于可视化）
6. CSV → 样本级别的抵抗指数

用法：
    python3 4-Biocide_format_conversion.py <input_csv> <output_dir>
"""

import pandas as pd
import json
import numpy as np
from pathlib import Path
from collections import defaultdict
import sys
import re

def load_biocide_data(csv_file):
    """加载CSV数据"""
    try:
        # 首先尝试标准读取
        df = pd.read_csv(csv_file)
        print(f"✓ 加载数据：{len(df)} 行")
        return df
    except pd.errors.ParserError as e:
        print(f"⚠️  CSV解析错误: {e}")
        print("🔧 尝试使用更健壮的解析方法...")
        
        # 使用更健壮的参数重新尝试
        try:
            df = pd.read_csv(csv_file, 
                           quoting=1,  # 使用quote_all
                           skipinitialspace=True,
                           on_bad_lines='skip',  # 跳过问题行
                           low_memory=False)
            print(f"✓ 使用健壮模式加载数据：{len(df)} 行")
            return df
        except Exception as e2:
            print(f"❌ 健壮模式也失败了: {e2}")
            sys.exit(1)

def parse_gene_info(sseqid):
    """从sseqid解析基因信息
    例如：lcl|NZ_LT594095.1_cds_WP_000377263.1_1849 -> WP_000377263.1
    """
    if pd.isna(sseqid):
        return None, None
    
    sseqid_str = str(sseqid)
    
    # 提取基因标识符
    if 'WP_' in sseqid_str:
        wp_match = re.search(r'WP_\d+\.\d+', sseqid_str)
        gene_id = wp_match.group() if wp_match else sseqid_str
    else:
        # 如果没有WP_格式，使用整个sseqid作为基因ID
        gene_id = sseqid_str
    
    # 提取数据库信息
    if 'lcl|' in sseqid_str:
        db_info = sseqid_str.split('lcl|')[1] if 'lcl|' in sseqid_str else sseqid_str
    else:
        db_info = sseqid_str
    
    return gene_id, db_info

def get_sample_id(filename):
    """从filename字段提取样本ID"""
    if pd.isna(filename):
        return None
    return str(filename).strip()

def classify_biocide_mechanism(gene_id):
    """根据基因ID分类生物杀灭抵抗机制"""
    if pd.isna(gene_id):
        return "Unknown"
    
    gene_str = str(gene_id).upper()
    
    # 基于常见的生物杀灭抵抗基因分类
    if any(term in gene_str for term in ['EFFLUX', 'ACR', 'MFS', 'RND']):
        return "Efflux_pump"
    elif any(term in gene_str for term in ['QAC', 'QACA', 'QACB']):
        return "QAC_resistance"
    elif any(term in gene_str for term in ['MERA', 'MERB', 'MERC']):
        return "Heavy_metal_resistance"
    elif any(term in gene_str for term in ['TELLURITE', 'TER']):
        return "Tellurite_resistance"
    elif any(term in gene_str for term in ['ARSENIC', 'ARS']):
        return "Arsenic_resistance"
    elif any(term in gene_str for term in ['COPPER', 'COP', 'CUE']):
        return "Copper_resistance"
    elif any(term in gene_str for term in ['SILVER', 'SIL']):
        return "Silver_resistance"
    elif any(term in gene_str for term in ['ZINC', 'CAD', 'CZC']):
        return "Zinc_cadmium_resistance"
    elif any(term in gene_str for term in ['STRESS', 'OSM']):
        return "Stress_response"
    elif any(term in gene_str for term in ['BIOFILM', 'PGA']):
        return "Biofilm_formation"
    else:
        return "Other_resistance"

def format_1_wide_gene_presence(df, output_dir):
    """格式1：宽表格式 - 样本×抵抗基因（0/1矩阵）"""
    print("\n=== 格式1：宽表格式（样本×抵抗基因presence/absence）===")
    
    # 创建样本-基因矩阵
    pivot_data = []
    for _, row in df.iterrows():
        sample_id = get_sample_id(row['filename'])
        if not sample_id:
            continue
        
        gene_id, db_info = parse_gene_info(row['sseqid'])
        if not gene_id:
            continue
            
        pivot_data.append({
            'Sample': sample_id,
            'Gene_ID': gene_id,
            'Database_Info': db_info,
            'Mechanism': classify_biocide_mechanism(gene_id)
        })
    
    pivot_df = pd.DataFrame(pivot_data)
    
    # 创建presence/absence矩阵
    presence_matrix = pd.crosstab(
        pivot_df['Sample'], 
        pivot_df['Gene_ID']
    ).astype(int)
    
    output_file = output_dir / "1-presence_absence_matrix.csv"
    presence_matrix.to_csv(output_file)
    print(f"✓ 输出：{output_file}")
    print(f"  维度：{presence_matrix.shape[0]} 样本 × {presence_matrix.shape[1]} 抵抗基因")
    
    return presence_matrix

def format_2_long_normalized(df, output_dir):
    """格式2：长表格式 - 规范化的tidy data"""
    print("\n=== 格式2：长表格式（规范化 tidy format）===")
    
    normalized_data = []
    for _, row in df.iterrows():
        sample_id = get_sample_id(row['filename'])
        if not sample_id:
            continue
        
        gene_id, db_info = parse_gene_info(row['sseqid'])
        if not gene_id:
            continue
            
        normalized_data.append({
            'Sample_ID': sample_id,
            'Query_Gene': row['qseqid'],
            'Gene_ID': gene_id,
            'Database_Info': db_info,
            'Resistance_Mechanism': classify_biocide_mechanism(gene_id),
            'Full_sseqid': row['sseqid']
        })
    
    tidy_df = pd.DataFrame(normalized_data)
    output_file = output_dir / "2-tidy_long_format.csv"
    tidy_df.to_csv(output_file, index=False)
    print(f"✓ 输出：{output_file}")
    print(f"  共 {len(tidy_df)} 条记录")
    
    return tidy_df

def format_3_resistance_summary(df, output_dir):
    """格式3：生物杀灭抵抗统计"""
    print("\n=== 格式3：生物杀灭抵抗统计表 ===")
    
    # 预处理数据
    processed_data = []
    for _, row in df.iterrows():
        sample_id = get_sample_id(row['filename'])
        if not sample_id:
            continue
        
        gene_id, db_info = parse_gene_info(row['sseqid'])
        if not gene_id:
            continue
            
        processed_data.append({
            'Sample': sample_id,
            'Gene_ID': gene_id,
            'Mechanism': classify_biocide_mechanism(gene_id)
        })
    
    processed_df = pd.DataFrame(processed_data)
    
    resistance_data = []
    for sample_id in processed_df['Sample'].unique():
        sample_df = processed_df[processed_df['Sample'] == sample_id]
        
        # 统计各类抵抗机制
        mechanism_counts = sample_df['Mechanism'].value_counts().to_dict()
        total_resistance_genes = len(sample_df)
        unique_genes = sample_df['Gene_ID'].nunique()
        
        # 获取具体的抵抗基因列表（前10个）
        top_genes = ', '.join(sample_df['Gene_ID'].unique()[:10])
        
        resistance_data.append({
            'Sample': sample_id,
            'Total_Resistance_Genes': total_resistance_genes,
            'Unique_Genes': unique_genes,
            'Efflux_pump': mechanism_counts.get('Efflux_pump', 0),
            'QAC_resistance': mechanism_counts.get('QAC_resistance', 0),
            'Heavy_metal_resistance': mechanism_counts.get('Heavy_metal_resistance', 0),
            'Tellurite_resistance': mechanism_counts.get('Tellurite_resistance', 0),
            'Arsenic_resistance': mechanism_counts.get('Arsenic_resistance', 0),
            'Copper_resistance': mechanism_counts.get('Copper_resistance', 0),
            'Silver_resistance': mechanism_counts.get('Silver_resistance', 0),
            'Zinc_cadmium_resistance': mechanism_counts.get('Zinc_cadmium_resistance', 0),
            'Stress_response': mechanism_counts.get('Stress_response', 0),
            'Biofilm_formation': mechanism_counts.get('Biofilm_formation', 0),
            'Other_resistance': mechanism_counts.get('Other_resistance', 0),
            'Top_Genes': top_genes
        })
    
    resistance_df = pd.DataFrame(resistance_data)
    output_file = output_dir / "3-biocide_resistance_summary.csv"
    resistance_df.to_csv(output_file, index=False)
    print(f"✓ 输出：{output_file}")
    print(f"  统计了 {len(resistance_df)} 个样本")
    
    if len(resistance_df) > 0:
        print("\n样本抵抗基因数统计:")
        print(resistance_df[['Sample', 'Total_Resistance_Genes', 'Unique_Genes']].head(10).to_string(index=False))
    
    return resistance_df

def format_4_gene_cooccurrence(df, output_dir):
    """格式4：抵抗基因共现矩阵"""
    print("\n=== 格式4：抵抗基因共现矩阵 ===")
    
    # 预处理获取基因IDs
    sample_genes = defaultdict(set)
    for _, row in df.iterrows():
        sample_id = get_sample_id(row['filename'])
        gene_id, _ = parse_gene_info(row['sseqid'])
        if sample_id and gene_id:
            sample_genes[sample_id].add(gene_id)
    
    # 统计基因共现
    gene_cooccurrence = defaultdict(lambda: defaultdict(int))
    
    for sample_id, genes in sample_genes.items():
        genes_list = list(genes)
        for i, gene1 in enumerate(genes_list):
            for gene2 in genes_list[i:]:
                if gene1 != gene2:
                    gene_cooccurrence[gene1][gene2] += 1
                    gene_cooccurrence[gene2][gene1] += 1
                else:
                    gene_cooccurrence[gene1][gene2] += 1
    
    # 转换为DataFrame
    all_genes = sorted(set(g for genes in sample_genes.values() for g in genes))
    cooccurrence_matrix = pd.DataFrame(0, index=all_genes, columns=all_genes)
    
    for gene1 in gene_cooccurrence:
        for gene2 in gene_cooccurrence[gene1]:
            if gene1 in cooccurrence_matrix.index and gene2 in cooccurrence_matrix.columns:
                cooccurrence_matrix.loc[gene1, gene2] = gene_cooccurrence[gene1][gene2]
    
    output_file = output_dir / "4-gene_cooccurrence_matrix.csv"
    cooccurrence_matrix.to_csv(output_file)
    print(f"✓ 输出：{output_file}")
    print(f"  维度：{cooccurrence_matrix.shape[0]} 抵抗基因")
    
    if len(cooccurrence_matrix) > 0:
        print(f"\n共现最频繁的基因对（Top 10）:")
        # 找出最高的共现
        coocc_flat = []
        for i, gene1 in enumerate(all_genes):
            for j, gene2 in enumerate(all_genes):
                if i < j:
                    coocc_flat.append((gene1, gene2, cooccurrence_matrix.loc[gene1, gene2]))
        
        coocc_flat.sort(key=lambda x: x[2], reverse=True)
        for gene1, gene2, count in coocc_flat[:10]:
            print(f"  {gene1} ↔ {gene2}: {count} 个样本")
    
    return cooccurrence_matrix

def format_5_json_network(df, output_dir):
    """格式5：JSON格式 - 用于可视化（如Cytoscape）"""
    print("\n=== 格式5：JSON网络格式 ===")
    
    nodes = []
    edges = []
    node_set = set()
    
    # 预处理数据
    sample_data = defaultdict(list)
    for _, row in df.iterrows():
        sample_id = get_sample_id(row['filename'])
        gene_id, db_info = parse_gene_info(row['sseqid'])
        if sample_id and gene_id:
            sample_data[sample_id].append({
                'gene_id': gene_id,
                'mechanism': classify_biocide_mechanism(gene_id),
                'db_info': db_info
            })
    
    # 添加样本节点和基因节点
    for sample_id, genes in sample_data.items():
        # 添加样本节点
        if sample_id not in node_set:
            nodes.append({
                'id': sample_id,
                'label': sample_id,
                'type': 'sample',
                'size': len(genes)
            })
            node_set.add(sample_id)
        
        # 添加基因节点和连接
        for gene_info in genes:
            gene_id = gene_info['gene_id']
            if gene_id not in node_set:
                nodes.append({
                    'id': gene_id,
                    'label': gene_id,
                    'type': 'resistance_gene',
                    'mechanism': gene_info['mechanism'],
                    'size': 10
                })
                node_set.add(gene_id)
            
            # 添加边（样本-基因关系）
            edges.append({
                'source': sample_id,
                'target': gene_id,
                'type': 'carries',
                'weight': 1
            })
    
    network_data = {
        'nodes': nodes,
        'edges': edges,
        'metadata': {
            'total_samples': len(sample_data),
            'total_resistance_genes': len([n for n in nodes if n['type'] == 'resistance_gene']),
            'total_relationships': len(edges)
        }
    }
    
    output_file = output_dir / "5-network_data.json"
    with open(output_file, 'w', encoding='utf-8') as f:
        json.dump(network_data, f, ensure_ascii=False, indent=2)
    
    print(f"✓ 输出：{output_file}")
    print(f"  节点数：{len(nodes)}")
    print(f"  边数：{len(edges)}")
    
    return network_data

def format_6_sample_metrics(df, output_dir):
    """格式6：样本级别的抵抗指数"""
    print("\n=== 格式6：样本级别抵抗指数 ===")
    
    # 预处理数据
    sample_data = defaultdict(list)
    for _, row in df.iterrows():
        sample_id = get_sample_id(row['filename'])
        gene_id, db_info = parse_gene_info(row['sseqid'])
        if sample_id and gene_id:
            sample_data[sample_id].append({
                'gene_id': gene_id,
                'mechanism': classify_biocide_mechanism(gene_id)
            })
    
    metrics = []
    for sample_id, genes in sample_data.items():
        # 计算各种指数
        total_resistance_genes = len(genes)
        unique_genes = len(set(g['gene_id'] for g in genes))
        
        # 机制多样性指数（多少个不同的抵抗机制）
        mechanisms = [g['mechanism'] for g in genes]
        mechanism_diversity = len(set(mechanisms))
        
        # 各机制类别的计数
        mechanism_counts = defaultdict(int)
        for mech in mechanisms:
            mechanism_counts[mech] += 1
        
        # 抵抗指数（基于基因数量的相对评分）
        resistance_index = min(total_resistance_genes / 20.0, 10.0)  # 标准化到0-10
        
        # 重金属抵抗指数
        heavy_metal_genes = (mechanism_counts['Heavy_metal_resistance'] + 
                           mechanism_counts['Tellurite_resistance'] + 
                           mechanism_counts['Arsenic_resistance'] + 
                           mechanism_counts['Copper_resistance'] + 
                           mechanism_counts['Silver_resistance'] + 
                           mechanism_counts['Zinc_cadmium_resistance'])
        
        # 外排泵相关基因
        efflux_genes = mechanism_counts['Efflux_pump']
        
        metrics.append({
            'Sample': sample_id,
            'Total_Resistance_Genes': total_resistance_genes,
            'Unique_Genes': unique_genes,
            'Mechanism_Diversity': mechanism_diversity,
            'Efflux_pump_Genes': mechanism_counts['Efflux_pump'],
            'QAC_resistance_Genes': mechanism_counts['QAC_resistance'],
            'Heavy_metal_Total': heavy_metal_genes,
            'Stress_response_Genes': mechanism_counts['Stress_response'],
            'Biofilm_formation_Genes': mechanism_counts['Biofilm_formation'],
            'Other_Genes': mechanism_counts['Other_resistance'],
            'Resistance_Index': round(resistance_index, 2),
            'Heavy_Metal_Index': round(heavy_metal_genes / 5.0, 2),
            'Efflux_Ratio': round(efflux_genes / max(total_resistance_genes, 1), 2)
        })
    
    metrics_df = pd.DataFrame(metrics)
    output_file = output_dir / "6-sample_resistance_metrics.csv"
    metrics_df.to_csv(output_file, index=False)
    print(f"✓ 输出：{output_file}")
    
    if len(metrics_df) > 0:
        print(f"\n主要指标统计:")
        print(metrics_df[['Sample', 'Total_Resistance_Genes', 'Mechanism_Diversity', 'Resistance_Index']].head(10).to_string(index=False))
    
    return metrics_df

def format_7_mechanism_profile(df, output_dir):
    """格式7：抵抗机制谱"""
    print("\n=== 格式7：抵抗机制谱 ===")
    
    # 预处理数据
    sample_mechanisms = defaultdict(list)
    for _, row in df.iterrows():
        sample_id = get_sample_id(row['filename'])
        gene_id, _ = parse_gene_info(row['sseqid'])
        if sample_id and gene_id:
            mechanism = classify_biocide_mechanism(gene_id)
            sample_mechanisms[sample_id].append(mechanism)
    
    # 样本×机制类别矩阵
    mechanism_profiles = []
    all_mechanisms = set()
    for mechanisms in sample_mechanisms.values():
        all_mechanisms.update(mechanisms)
    
    for sample_id, mechanisms in sample_mechanisms.items():
        profile = {'Sample': sample_id}
        for mechanism in sorted(all_mechanisms):
            count = mechanisms.count(mechanism)
            profile[mechanism] = count
        mechanism_profiles.append(profile)
    
    mechanism_profile_df = pd.DataFrame(mechanism_profiles)
    output_file = output_dir / "7-biocide_mechanism_profile.csv"
    mechanism_profile_df.to_csv(output_file, index=False)
    print(f"✓ 输出：{output_file}")
    
    if len(mechanism_profile_df) > 0:
        print(f"\n抵抗机制分布概览:")
        print(mechanism_profile_df.head(10).to_string(index=False))
    
    return mechanism_profile_df

def generate_summary_report(output_dir, results):
    """生成总结报告"""
    print("\n" + "="*60)
    print("📊 生物杀灭抵抗数据转换总结报告")
    print("="*60)
    
    report = f"""
生物杀灭抵抗数据转换完成！

✓ 生成的格式：
  1. presence_absence_matrix.csv
     - 用途：机器学习、聚类分析、热力图可视化
     - 格式：样本 × 抵抗基因（0/1矩阵）
     - 适合工具：R ggplot2, Python seaborn, heatmap
  
  2. tidy_long_format.csv
     - 用途：ggplot2, tidyverse分析，统计检验
     - 格式：每行一个样本-基因关系
     - 适合工具：R ggplot2, dplyr, Python plotly
  
  3. biocide_resistance_summary.csv
     - 用途：快速了解每个样本的抵抗谱
     - 格式：样本 × 抵抗机制统计
     - 适合工具：Excel, 描述性统计
  
  4. gene_cooccurrence_matrix.csv
     - 用途：抵抗基因关联分析、网络分析
     - 格式：基因 × 基因（共现频率）
     - 适合工具：R igraph, Cytoscape, Gephi
  
  5. network_data.json
     - 用途：交互式网络可视化
     - 格式：图论格式（节点+边）
     - 适合工具：Cytoscape.js, D3.js, Gephi导入
  
  6. sample_resistance_metrics.csv
     - 用途：相关性分析、回归分析
     - 格式：样本 × 连续型指标
     - 适合工具：R ggplot2, 相关性热力图
  
  7. biocide_mechanism_profile.csv
     - 用途：样本分层、聚类、热力图
     - 格式：样本 × 抵抗机制类别（计数）
     - 适合工具：heatmap, 聚类分析

抵抗机制分类说明：
  - Efflux_pump: 外排泵相关基因
  - QAC_resistance: 季铵盐类化合物抵抗
  - Heavy_metal_resistance: 重金属抵抗（汞等）
  - Tellurite_resistance: 亚碲酸盐抵抗
  - Arsenic_resistance: 砷抵抗
  - Copper_resistance: 铜抵抗
  - Silver_resistance: 银抵抗
  - Zinc_cadmium_resistance: 锌镉抵抗
  - Stress_response: 压力应答
  - Biofilm_formation: 生物膜形成
  - Other_resistance: 其他抵抗机制

推荐分析流程：
  Step 1: 用 biocide_resistance_summary.csv 做初步描述
  Step 2: 用 presence_absence_matrix.csv 进行聚类
  Step 3: 用 gene_cooccurrence_matrix.csv 分析基因关联
  Step 4: 用 network_data.json 在Cytoscape中可视化
  Step 5: 用 sample_resistance_metrics.csv 进行相关性分析
"""
    
    report_file = output_dir / "README_生物杀灭抵抗数据格式说明.txt"
    with open(report_file, 'w', encoding='utf-8') as f:
        f.write(report)
    
    print(report)
    print(f"\n📄 详细说明已保存到：{report_file}")

def main():
    if len(sys.argv) < 2:
        print(__doc__)
        print("\n示例用法：")
        print("  python3 4-Biocide_format_conversion.py 生物杀灭抵抗_合并.csv ./biocide_output")
        sys.exit(1)
    
    input_file = Path(sys.argv[1])
    output_dir = Path(sys.argv[2] if len(sys.argv) > 2 else "biocide_output")
    
    if not input_file.exists():
        print(f"❌ 输入文件不存在：{input_file}")
        sys.exit(1)
    
    output_dir.mkdir(parents=True, exist_ok=True)
    print(f"📁 输出目录：{output_dir}\n")
    
    # 加载数据
    df = load_biocide_data(input_file)
    
    # 执行各种格式转换
    results = {
        'presence_absence': format_1_wide_gene_presence(df, output_dir),
        'tidy_long': format_2_long_normalized(df, output_dir),
        'resistance_summary': format_3_resistance_summary(df, output_dir),
        'cooccurrence': format_4_gene_cooccurrence(df, output_dir),
        'network': format_5_json_network(df, output_dir),
        'metrics': format_6_sample_metrics(df, output_dir),
        'mechanism_profile': format_7_mechanism_profile(df, output_dir),
    }
    
    # 生成总结报告
    generate_summary_report(output_dir, results)
    
    print("\n✅ 所有转换完成！")

if __name__ == "__main__":
    main()