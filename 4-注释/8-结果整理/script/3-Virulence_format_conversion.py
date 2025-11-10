#!/usr/bin/env python3
"""
毒力因子结果格式转换工具
将毒力因子数据整理为多种格式用于不同的数据分析

功能：
1. CSV → 宽表格式（样本×毒力因子基因）
2. CSV → 长表格式（规范化）
3. CSV → 毒力功能统计表
4. CSV → 基因共现矩阵
5. CSV → JSON格式（便于可视化）
6. CSV → 样本级别的毒力指数

用法：
    python3 3-Virulence_format_conversion.py <input_csv> <output_dir>
"""

import pandas as pd
import json
import numpy as np
from pathlib import Path
from collections import defaultdict
import sys
import re

def load_virulence_data(csv_file):
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

def parse_vfg_id(sseqid):
    """从sseqid解析VFG ID和功能信息
    例如：VFG050634(gb|WP_000389077.1) -> VFG050634
    """
    if pd.isna(sseqid):
        return None, None
    
    # 提取VFG ID
    vfg_match = re.search(r'VFG\d+', str(sseqid))
    vfg_id = vfg_match.group() if vfg_match else str(sseqid).split('(')[0]
    
    # 提取基因号
    gene_match = re.search(r'\((.*?)\)', str(sseqid))
    gene_accession = gene_match.group(1) if gene_match else str(sseqid)
    
    return vfg_id, gene_accession

def get_sample_id(filename):
    """从filename字段提取样本ID"""
    if pd.isna(filename):
        return None
    return str(filename).strip()

def classify_virulence_function(vfg_id):
    """根据VFG ID分类毒力功能"""
    if pd.isna(vfg_id):
        return "Unknown"
    
    vfg_str = str(vfg_id).upper()
    
    # 基于VFG数据库的功能分类
    if 'VFG050' in vfg_str:
        # 根据VFG编号范围进行粗分类
        vfg_num = re.search(r'VFG(\d+)', vfg_str)
        if vfg_num:
            num = int(vfg_num.group(1))
            if 50600 <= num <= 50700:
                return "Adhesion"
            elif 50700 <= num <= 50800:
                return "Toxin"
            elif 50800 <= num <= 50900:
                return "Iron_acquisition"
            elif 50900 <= num <= 51000:
                return "Immune_evasion"
            elif 51000 <= num <= 51100:
                return "Secretion_system"
            else:
                return "Other_virulence"
    
    return "Unknown"

def format_1_wide_gene_presence(df, output_dir):
    """格式1：宽表格式 - 样本×毒力基因（0/1矩阵）"""
    print("\n=== 格式1：宽表格式（样本×毒力基因presence/absence）===")
    
    # 创建样本-基因矩阵
    pivot_data = []
    for _, row in df.iterrows():
        sample_id = get_sample_id(row['filename'])
        if not sample_id:
            continue
        
        vfg_id, gene_accession = parse_vfg_id(row['sseqid'])
        if not vfg_id:
            continue
            
        pivot_data.append({
            'Sample': sample_id,
            'VFG_ID': vfg_id,
            'Gene_Accession': gene_accession,
            'Function': classify_virulence_function(vfg_id)
        })
    
    pivot_df = pd.DataFrame(pivot_data)
    
    # 创建presence/absence矩阵
    presence_matrix = pd.crosstab(
        pivot_df['Sample'], 
        pivot_df['VFG_ID']
    ).astype(int)
    
    output_file = output_dir / "1-presence_absence_matrix.csv"
    presence_matrix.to_csv(output_file)
    print(f"✓ 输出：{output_file}")
    print(f"  维度：{presence_matrix.shape[0]} 样本 × {presence_matrix.shape[1]} 毒力基因")
    
    return presence_matrix

def format_2_long_normalized(df, output_dir):
    """格式2：长表格式 - 规范化的tidy data"""
    print("\n=== 格式2：长表格式（规范化 tidy format）===")
    
    normalized_data = []
    for _, row in df.iterrows():
        sample_id = get_sample_id(row['filename'])
        if not sample_id:
            continue
        
        vfg_id, gene_accession = parse_vfg_id(row['sseqid'])
        if not vfg_id:
            continue
            
        normalized_data.append({
            'Sample_ID': sample_id,
            'Query_Gene': row['qseqid'],
            'VFG_ID': vfg_id,
            'Gene_Accession': gene_accession,
            'Virulence_Function': classify_virulence_function(vfg_id),
            'Full_sseqid': row['sseqid']
        })
    
    tidy_df = pd.DataFrame(normalized_data)
    output_file = output_dir / "2-tidy_long_format.csv"
    tidy_df.to_csv(output_file, index=False)
    print(f"✓ 输出：{output_file}")
    print(f"  共 {len(tidy_df)} 条记录")
    
    return tidy_df

def format_3_virulence_summary(df, output_dir):
    """格式3：毒力功能统计"""
    print("\n=== 格式3：毒力功能统计表 ===")
    
    # 预处理数据
    processed_data = []
    for _, row in df.iterrows():
        sample_id = get_sample_id(row['filename'])
        if not sample_id:
            continue
        
        vfg_id, gene_accession = parse_vfg_id(row['sseqid'])
        if not vfg_id:
            continue
            
        processed_data.append({
            'Sample': sample_id,
            'VFG_ID': vfg_id,
            'Function': classify_virulence_function(vfg_id)
        })
    
    processed_df = pd.DataFrame(processed_data)
    
    virulence_data = []
    for sample_id in processed_df['Sample'].unique():
        sample_df = processed_df[processed_df['Sample'] == sample_id]
        
        # 统计各类毒力功能
        function_counts = sample_df['Function'].value_counts().to_dict()
        total_virulence_genes = len(sample_df)
        unique_vfgs = sample_df['VFG_ID'].nunique()
        
        # 获取具体的毒力基因列表（前10个）
        top_vfgs = ', '.join(sample_df['VFG_ID'].unique()[:10])
        
        virulence_data.append({
            'Sample': sample_id,
            'Total_Virulence_Genes': total_virulence_genes,
            'Unique_VFGs': unique_vfgs,
            'Adhesion': function_counts.get('Adhesion', 0),
            'Toxin': function_counts.get('Toxin', 0),
            'Iron_acquisition': function_counts.get('Iron_acquisition', 0),
            'Immune_evasion': function_counts.get('Immune_evasion', 0),
            'Secretion_system': function_counts.get('Secretion_system', 0),
            'Other_virulence': function_counts.get('Other_virulence', 0),
            'Unknown': function_counts.get('Unknown', 0),
            'Top_VFGs': top_vfgs
        })
    
    virulence_df = pd.DataFrame(virulence_data)
    output_file = output_dir / "3-virulence_summary.csv"
    virulence_df.to_csv(output_file, index=False)
    print(f"✓ 输出：{output_file}")
    print(f"  统计了 {len(virulence_df)} 个样本")
    
    if len(virulence_df) > 0:
        print("\n样本毒力基因数统计:")
        print(virulence_df[['Sample', 'Total_Virulence_Genes', 'Unique_VFGs']].head(10).to_string(index=False))
    
    return virulence_df

def format_4_gene_cooccurrence(df, output_dir):
    """格式4：毒力基因共现矩阵"""
    print("\n=== 格式4：毒力基因共现矩阵 ===")
    
    # 预处理获取VFG IDs
    sample_genes = defaultdict(set)
    for _, row in df.iterrows():
        sample_id = get_sample_id(row['filename'])
        vfg_id, _ = parse_vfg_id(row['sseqid'])
        if sample_id and vfg_id:
            sample_genes[sample_id].add(vfg_id)
    
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
    print(f"  维度：{cooccurrence_matrix.shape[0]} 毒力基因")
    
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
        vfg_id, gene_accession = parse_vfg_id(row['sseqid'])
        if sample_id and vfg_id:
            sample_data[sample_id].append({
                'vfg_id': vfg_id,
                'function': classify_virulence_function(vfg_id),
                'gene_accession': gene_accession
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
            vfg_id = gene_info['vfg_id']
            if vfg_id not in node_set:
                nodes.append({
                    'id': vfg_id,
                    'label': vfg_id,
                    'type': 'virulence_gene',
                    'function': gene_info['function'],
                    'size': 10
                })
                node_set.add(vfg_id)
            
            # 添加边（样本-基因关系）
            edges.append({
                'source': sample_id,
                'target': vfg_id,
                'type': 'carries',
                'weight': 1
            })
    
    network_data = {
        'nodes': nodes,
        'edges': edges,
        'metadata': {
            'total_samples': len(sample_data),
            'total_virulence_genes': len([n for n in nodes if n['type'] == 'virulence_gene']),
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
    """格式6：样本级别的毒力指数"""
    print("\n=== 格式6：样本级别毒力指数 ===")
    
    # 预处理数据
    sample_data = defaultdict(list)
    for _, row in df.iterrows():
        sample_id = get_sample_id(row['filename'])
        vfg_id, gene_accession = parse_vfg_id(row['sseqid'])
        if sample_id and vfg_id:
            sample_data[sample_id].append({
                'vfg_id': vfg_id,
                'function': classify_virulence_function(vfg_id)
            })
    
    metrics = []
    for sample_id, genes in sample_data.items():
        # 计算各种指数
        total_virulence_genes = len(genes)
        unique_vfgs = len(set(g['vfg_id'] for g in genes))
        
        # 功能多样性指数（多少个不同的毒力功能类别）
        functions = [g['function'] for g in genes]
        function_diversity = len(set(functions))
        
        # 各功能类别的计数
        function_counts = defaultdict(int)
        for func in functions:
            function_counts[func] += 1
        
        # 毒力指数（基于基因数量的相对评分）
        virulence_index = min(total_virulence_genes / 10.0, 10.0)  # 标准化到0-10
        
        # 功能完整性指数（覆盖了多少个主要功能类别）
        major_functions = ['Adhesion', 'Toxin', 'Iron_acquisition', 'Immune_evasion', 'Secretion_system']
        function_completeness = sum(1 for func in major_functions if function_counts[func] > 0) / len(major_functions)
        
        metrics.append({
            'Sample': sample_id,
            'Total_Virulence_Genes': total_virulence_genes,
            'Unique_VFGs': unique_vfgs,
            'Function_Diversity': function_diversity,
            'Adhesion_Genes': function_counts['Adhesion'],
            'Toxin_Genes': function_counts['Toxin'],
            'Iron_acquisition_Genes': function_counts['Iron_acquisition'],
            'Immune_evasion_Genes': function_counts['Immune_evasion'],
            'Secretion_system_Genes': function_counts['Secretion_system'],
            'Other_Genes': function_counts['Other_virulence'] + function_counts['Unknown'],
            'Virulence_Index': round(virulence_index, 2),
            'Function_Completeness': round(function_completeness, 2)
        })
    
    metrics_df = pd.DataFrame(metrics)
    output_file = output_dir / "6-sample_virulence_metrics.csv"
    metrics_df.to_csv(output_file, index=False)
    print(f"✓ 输出：{output_file}")
    
    if len(metrics_df) > 0:
        print(f"\n主要指标统计:")
        print(metrics_df[['Sample', 'Total_Virulence_Genes', 'Function_Diversity', 'Virulence_Index']].head(10).to_string(index=False))
    
    return metrics_df

def format_7_function_profile(df, output_dir):
    """格式7：毒力功能谱"""
    print("\n=== 格式7：毒力功能谱 ===")
    
    # 预处理数据
    sample_functions = defaultdict(list)
    for _, row in df.iterrows():
        sample_id = get_sample_id(row['filename'])
        vfg_id, _ = parse_vfg_id(row['sseqid'])
        if sample_id and vfg_id:
            function = classify_virulence_function(vfg_id)
            sample_functions[sample_id].append(function)
    
    # 样本×功能类别矩阵
    function_profiles = []
    all_functions = set()
    for functions in sample_functions.values():
        all_functions.update(functions)
    
    for sample_id, functions in sample_functions.items():
        profile = {'Sample': sample_id}
        for function in sorted(all_functions):
            count = functions.count(function)
            profile[function] = count
        function_profiles.append(profile)
    
    function_profile_df = pd.DataFrame(function_profiles)
    output_file = output_dir / "7-virulence_function_profile.csv"
    function_profile_df.to_csv(output_file, index=False)
    print(f"✓ 输出：{output_file}")
    
    if len(function_profile_df) > 0:
        print(f"\n毒力功能分布概览:")
        print(function_profile_df.head(10).to_string(index=False))
    
    return function_profile_df

def generate_summary_report(output_dir, results):
    """生成总结报告"""
    print("\n" + "="*60)
    print("📊 毒力因子数据转换总结报告")
    print("="*60)
    
    report = f"""
毒力因子数据转换完成！

✓ 生成的格式：
  1. presence_absence_matrix.csv
     - 用途：机器学习、聚类分析、热力图可视化
     - 格式：样本 × VFG基因（0/1矩阵）
     - 适合工具：R ggplot2, Python seaborn, heatmap
  
  2. tidy_long_format.csv
     - 用途：ggplot2, tidyverse分析，统计检验
     - 格式：每行一个样本-基因关系
     - 适合工具：R ggplot2, dplyr, Python plotly
  
  3. virulence_summary.csv
     - 用途：快速了解每个样本的毒力谱
     - 格式：样本 × 毒力功能统计
     - 适合工具：Excel, 描述性统计
  
  4. gene_cooccurrence_matrix.csv
     - 用途：毒力基因关联分析、网络分析
     - 格式：基因 × 基因（共现频率）
     - 适合工具：R igraph, Cytoscape, Gephi
  
  5. network_data.json
     - 用途：交互式网络可视化
     - 格式：图论格式（节点+边）
     - 适合工具：Cytoscape.js, D3.js, Gephi导入
  
  6. sample_virulence_metrics.csv
     - 用途：相关性分析、回归分析
     - 格式：样本 × 连续型指标
     - 适合工具：R ggplot2, 相关性热力图
  
  7. virulence_function_profile.csv
     - 用途：样本分层、聚类、热力图
     - 格式：样本 × 毒力功能类别（计数）
     - 适合工具：heatmap, 聚类分析

毒力功能分类说明：
  - Adhesion: 黏附相关基因
  - Toxin: 毒素相关基因  
  - Iron_acquisition: 铁获取相关基因
  - Immune_evasion: 免疫逃逸相关基因
  - Secretion_system: 分泌系统相关基因
  - Other_virulence: 其他毒力相关基因
  - Unknown: 未知功能基因

推荐分析流程：
  Step 1: 用 virulence_summary.csv 做初步描述
  Step 2: 用 presence_absence_matrix.csv 进行聚类
  Step 3: 用 gene_cooccurrence_matrix.csv 分析基因关联
  Step 4: 用 network_data.json 在Cytoscape中可视化
  Step 5: 用 sample_virulence_metrics.csv 进行相关性分析
"""
    
    report_file = output_dir / "README_毒力因子数据格式说明.txt"
    with open(report_file, 'w', encoding='utf-8') as f:
        f.write(report)
    
    print(report)
    print(f"\n📄 详细说明已保存到：{report_file}")

def main():
    if len(sys.argv) < 2:
        print(__doc__)
        print("\n示例用法：")
        print("  python3 3-Virulence_format_conversion.py 毒力因子_合并.csv ./virulence_output")
        sys.exit(1)
    
    input_file = Path(sys.argv[1])
    output_dir = Path(sys.argv[2] if len(sys.argv) > 2 else "virulence_output")
    
    if not input_file.exists():
        print(f"❌ 输入文件不存在：{input_file}")
        sys.exit(1)
    
    output_dir.mkdir(parents=True, exist_ok=True)
    print(f"📁 输出目录：{output_dir}\n")
    
    # 加载数据
    df = load_virulence_data(input_file)
    
    # 执行各种格式转换
    results = {
        'presence_absence': format_1_wide_gene_presence(df, output_dir),
        'tidy_long': format_2_long_normalized(df, output_dir),
        'virulence_summary': format_3_virulence_summary(df, output_dir),
        'cooccurrence': format_4_gene_cooccurrence(df, output_dir),
        'network': format_5_json_network(df, output_dir),
        'metrics': format_6_sample_metrics(df, output_dir),
        'function_profile': format_7_function_profile(df, output_dir),
    }
    
    # 生成总结报告
    generate_summary_report(output_dir, results)
    
    print("\n✅ 所有转换完成！")

if __name__ == "__main__":
    main()