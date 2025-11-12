#!/usr/bin/env python3
"""
AMRFinder 结果格式转换工具
将抗生素耐药基因数据整理为多种格式用于不同的数据分析

功能：
0. CSV → 样本AMR总数统计
1. CSV → 宽表格式（样本×耐药基因）
2. CSV → 长表格式（规范化）
3. CSV → 耐药谱系统计表
4. CSV → 基因共现矩阵
5. CSV → JSON格式（便于可视化）
6. CSV → 样本级别的耐药指数

用法：
    python3 2-AMR_format_conversion.py <input_csv> <output_dir> [是否输出具体文件]

第三个参数可选（默认“是”）：
    - “是/yes” 输出目前所有格式。
    - “否/no” 仅输出样本AMR总数文件。
"""

import pandas as pd
import json
import numpy as np
from pathlib import Path
from collections import defaultdict
import sys

DEFAULT_FULL_OUTPUT_FLAG = "是"
FULL_OUTPUT_TRUE = {"是", "yes", "y", "true", "1", "all", "full"}
FULL_OUTPUT_FALSE = {"否", "no", "n", "false", "0", "none"}

def load_amr_data(csv_file):
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
            print("🔧 尝试逐行读取并清理数据...")
            
            # 最后的备选方案：逐行读取和清理
            return load_amr_data_robust(csv_file)

def load_amr_data_robust(csv_file):
    """健壮的CSV数据读取函数，处理格式问题"""
    import csv
    import io
    
    print("📖 正在逐行读取和清理CSV文件...")
    
    # 读取原始文件内容
    with open(csv_file, 'r', encoding='utf-8', errors='ignore') as f:
        content = f.read()
    
    # 清理内容：移除多余的换行符
    lines = content.split('\n')
    header = lines[0]
    expected_cols = len(header.split(','))
    
    cleaned_lines = [header]
    current_line = ""
    
    for line in lines[1:]:
        if not line.strip():
            continue
            
        current_line += " " + line.strip() if current_line else line.strip()
        
        # 检查当前行是否有正确的列数
        if current_line.count(',') >= expected_cols - 1:
            # 尝试解析这一行
            try:
                cols = current_line.split(',')
                if len(cols) >= expected_cols:
                    # 如果列数太多，尝试合并多余的列到最后一列
                    if len(cols) > expected_cols:
                        fixed_cols = cols[:expected_cols-1] + [','.join(cols[expected_cols-1:])]
                        current_line = ','.join(fixed_cols)
                    cleaned_lines.append(current_line)
                    current_line = ""
            except:
                continue
    
    # 如果还有未完成的行
    if current_line.strip():
        cleaned_lines.append(current_line)
    
    # 创建清理后的CSV内容
    cleaned_content = '\n'.join(cleaned_lines)
    
    # 使用StringIO读取清理后的内容
    try:
        df = pd.read_csv(io.StringIO(cleaned_content))
        print(f"✓ 健壮模式加载数据：{len(df)} 行")
        return df
    except Exception as e:
        print(f"❌ 最终读取失败: {e}")
        # 如果仍然失败，返回空DataFrame但包含正确的列
        columns = header.split(',')
        return pd.DataFrame(columns=columns)

def get_sample_id(filename):
    """从filename字段提取样本ID"""
    if pd.isna(filename):
        return None
    # 格式: DRR033181_AMRFinder.tsv -> DRR033181
    return str(filename).replace('_AMRFinder.tsv', '').strip()


def parse_full_output_flag(value):
    """解析“是否输出具体文件”参数"""
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
    """输出每个样本的AMR总数"""
    print("\n=== 样本AMR总数统计 ===")
    temp_df = df.copy()
    temp_df['Sample'] = temp_df['filename'].map(get_sample_id)
    temp_df = temp_df.dropna(subset=['Sample'])
    temp_df = temp_df[temp_df['Sample'].astype(str).str.strip() != ""]
    totals = (
        temp_df.groupby('Sample')
        .size()
        .reset_index(name='Total_AMR_Genes')
        .sort_values('Sample')
    )
    output_file = output_dir / "0-amr_sample_totals.csv"
    totals.to_csv(output_file, index=False)
    print(f"✓ 输出：{output_file}")
    if not totals.empty:
        print(totals.to_string(index=False))
    else:
        print("  （无有效样本）")
    return totals, output_file

def format_1_wide_gene_presence(df, output_dir):
    """格式1：宽表格式 - 样本×基因（0/1矩阵）"""
    print("\n=== 格式1：宽表格式（样本×基因presence/absence）===")
    
    # 创建样本-基因矩阵
    pivot_data = []
    for _, row in df.iterrows():
        sample_id = get_sample_id(row['filename'])
        if not sample_id:
            continue
        
        element_symbol = row['Element symbol']
        element_name = row['Element name']
        
        pivot_data.append({
            'Sample': sample_id,
            'Gene_Symbol': element_symbol,
            'Gene_Name': element_name,
            'Type': row['Type'],
            'Subtype': row['Subtype']
        })
    
    pivot_df = pd.DataFrame(pivot_data)
    
    # 创建presence/absence矩阵
    presence_matrix = pd.crosstab(
        pivot_df['Sample'], 
        pivot_df['Gene_Symbol']
    ).astype(int)
    
    output_file = output_dir / "1-presence_absence_matrix.csv"
    presence_matrix.to_csv(output_file)
    print(f"✓ 输出：{output_file}")
    print(f"  维度：{presence_matrix.shape[0]} 样本 × {presence_matrix.shape[1]} 基因")
    
    return presence_matrix

def format_2_long_normalized(df, output_dir):
    """格式2：长表格式 - 规范化的tidy data"""
    print("\n=== 格式2：长表格式（规范化 tidy format）===")
    
    normalized_data = []
    for _, row in df.iterrows():
        sample_id = get_sample_id(row['filename'])
        if not sample_id:
            continue
        
        normalized_data.append({
            'Sample_ID': sample_id,
            'Gene_Symbol': row['Element symbol'],
            'Gene_Name': row['Element name'],
            'Drug_Class': row['Class'],
            'Drug_Subclass': row['Subclass'],
            'Type': row['Type'],
            'Scope': row['Scope'],
            'Method': row['Method'],
            'Identity_%': row['% Identity to reference'],
            'Coverage_%': row['% Coverage of reference'],
            'Status': row['Scope']  # core/plus
        })
    
    tidy_df = pd.DataFrame(normalized_data)
    output_file = output_dir / "2-tidy_long_format.csv"
    tidy_df.to_csv(output_file, index=False)
    print(f"✓ 输出：{output_file}")
    print(f"  共 {len(tidy_df)} 条记录")
    
    return tidy_df

def format_3_phenotype_summary(df, output_dir):
    """格式3：耐药表型统计"""
    print("\n=== 格式3：耐药表型统计表 ===")
    
    phenotype_data = []
    for sample_id in df['filename'].dropna().unique():
        sample_id = get_sample_id(sample_id)
        if not sample_id:
            continue
        
        sample_df = df[df['filename'] == sample_id.replace('_AMRFinder.tsv', '') + '_AMRFinder.tsv'].copy()
        
        # 统计各类耐药
        drug_classes = sample_df['Class'].value_counts().to_dict()
        core_genes = len(sample_df[sample_df['Scope'] == 'core'])
        plus_genes = len(sample_df[sample_df['Scope'] == 'plus'])
        total_genes = len(sample_df)
        
        # 获取具体的药物亚类
        subclass_values = sample_df['Subclass'].dropna().unique()[:10]  # 移除NaN并取前10个
        subclasses = ', '.join(str(x) for x in subclass_values)  # 确保所有值都是字符串
        
        phenotype_data.append({
            'Sample': sample_id,
            'Total_ARGs': total_genes,
            'Core_ARGs': core_genes,
            'Plus_ARGs': plus_genes,
            'BETA_LACTAM': drug_classes.get('BETA-LACTAM', 0),
            'AMINOGLYCOSIDE': drug_classes.get('AMINOGLYCOSIDE', 0),
            'TETRACYCLINE': drug_classes.get('TETRACYCLINE', 0),
            'SULFONAMIDE': drug_classes.get('SULFONAMIDE', 0),
            'PHENICOL': drug_classes.get('PHENICOL', 0),
            'EFFLUX': drug_classes.get('EFFLUX', 0),
            'Other_Classes': drug_classes.get('STRESS', 0),
            'Primary_Phenotypes': subclasses
        })
    
    phenotype_df = pd.DataFrame(phenotype_data)
    output_file = output_dir / "3-phenotype_summary.csv"
    phenotype_df.to_csv(output_file, index=False)
    print(f"✓ 输出：{output_file}")
    print(f"  统计了 {len(phenotype_df)} 个样本")
    print("\n样本耐药基因数统计:")
    print(phenotype_df[['Sample', 'Total_ARGs', 'Core_ARGs', 'Plus_ARGs']].to_string(index=False))
    
    return phenotype_df

def format_4_gene_cooccurrence(df, output_dir):
    """格式4：基因共现矩阵"""
    print("\n=== 格式4：基因共现矩阵 ===")
    
    # 统计哪些基因在同一样本中出现
    gene_cooccurrence = defaultdict(lambda: defaultdict(int))
    
    for filename in df['filename'].dropna().unique():
        sample_df = df[df['filename'] == filename]
        genes = sample_df['Element symbol'].unique()
        
        for i, gene1 in enumerate(genes):
            for gene2 in genes[i:]:
                if gene1 != gene2:
                    gene_cooccurrence[gene1][gene2] += 1
                    gene_cooccurrence[gene2][gene1] += 1
                elif gene1 == gene2:
                    gene_cooccurrence[gene1][gene2] += 1
    
    # 转换为DataFrame
    all_genes = sorted(set(df['Element symbol'].unique()))
    cooccurrence_matrix = pd.DataFrame(0, index=all_genes, columns=all_genes)
    
    for gene1 in gene_cooccurrence:
        for gene2 in gene_cooccurrence[gene1]:
            cooccurrence_matrix.loc[gene1, gene2] = gene_cooccurrence[gene1][gene2]
    
    output_file = output_dir / "4-gene_cooccurrence_matrix.csv"
    cooccurrence_matrix.to_csv(output_file)
    print(f"✓ 输出：{output_file}")
    print(f"  维度：{cooccurrence_matrix.shape[0]} 基因")
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
    
    # 1. 样本节点和基因节点
    for filename in df['filename'].dropna().unique():
        sample_id = get_sample_id(filename)
        if not sample_id:
            continue
        
        sample_df = df[df['filename'] == filename]
        
        # 添加样本节点
        if sample_id not in node_set:
            nodes.append({
                'id': sample_id,
                'label': sample_id,
                'type': 'sample',
                'size': len(sample_df)
            })
            node_set.add(sample_id)
        
        # 添加基因节点和连接
        for _, row in sample_df.iterrows():
            gene_symbol = row['Element symbol']
            if gene_symbol not in node_set:
                nodes.append({
                    'id': gene_symbol,
                    'label': gene_symbol,
                    'type': 'gene',
                    'drug_class': row['Class'],
                    'size': 10
                })
                node_set.add(gene_symbol)
            
            # 添加边（样本-基因关系）
            edges.append({
                'source': sample_id,
                'target': gene_symbol,
                'type': 'carries',
                'weight': 1
            })
    
    network_data = {
        'nodes': nodes,
        'edges': edges,
        'metadata': {
            'total_samples': len(set(get_sample_id(f) for f in df['filename'].dropna())),
            'total_genes': len(set(df['Element symbol'])),
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
    """格式6：样本级别的耐药指数"""
    print("\n=== 格式6：样本级别耐药指数 ===")
    
    metrics = []
    for filename in df['filename'].dropna().unique():
        sample_id = get_sample_id(filename)
        if not sample_id:
            continue
        
        sample_df = df[df['filename'] == filename]
        
        # 计算各种指数
        total_args = len(sample_df)
        core_args = len(sample_df[sample_df['Scope'] == 'core'])
        plus_args = len(sample_df[sample_df['Scope'] == 'plus'])
        
        # 多药耐药指数（多少个不同的药物类别）
        drug_classes = sample_df['Class'].nunique()
        
        # 平均身份识别度
        avg_identity = sample_df['% Identity to reference'].mean()
        avg_coverage = sample_df['% Coverage of reference'].mean()
        
        # 完整性指标
        complete_genes = len(sample_df[sample_df['% Coverage of reference'] >= 90])
        partial_genes = total_args - complete_genes
        
        # 外排泵基因
        efflux_genes = len(sample_df[sample_df['Type'] == 'AMR'].copy()
                           .query('`Element symbol`.str.contains("ade|amv|tet|cx", case=False, na=False)', engine='python'))
        
        # 碳青霉烯耐药相关
        carbapenem_args = len(sample_df[sample_df['Subclass'].str.contains('CARBAPENEM', na=False)])
        
        metrics.append({
            'Sample': sample_id,
            'Total_ARGs': total_args,
            'Core_ARGs': core_args,
            'Plus_ARGs': plus_args,
            'Unique_Drug_Classes': drug_classes,
            'Avg_Identity_%': round(avg_identity, 2),
            'Avg_Coverage_%': round(avg_coverage, 2),
            'Complete_Genes': complete_genes,
            'Partial_Genes': partial_genes,
            'Efflux_Pump_Genes': efflux_genes,
            'Carbapenem_ARGs': carbapenem_args,
            'MultiDrug_Resistance_Index': round(total_args / 12, 2),  # 基于平均值的相对指数
        })
    
    metrics_df = pd.DataFrame(metrics)
    output_file = output_dir / "6-sample_resistance_metrics.csv"
    metrics_df.to_csv(output_file, index=False)
    print(f"✓ 输出：{output_file}")
    print(f"\n主要指标统计:")
    print(metrics_df[['Sample', 'Total_ARGs', 'Unique_Drug_Classes', 'MultiDrug_Resistance_Index']].to_string(index=False))
    
    return metrics_df

def format_7_drug_class_profile(df, output_dir):
    """格式7：药物类别耐药谱"""
    print("\n=== 格式7：药物类别耐药谱 ===")
    
    # 样本×药物类别矩阵
    drug_profiles = []
    for filename in df['filename'].dropna().unique():
        sample_id = get_sample_id(filename)
        if not sample_id:
            continue
        
        sample_df = df[df['filename'] == filename]
        
        profile = {'Sample': sample_id}
        # 获取所有非NaN的Class值并排序
        unique_classes = df['Class'].dropna().unique()
        for drug_class in sorted(unique_classes):
            count = len(sample_df[sample_df['Class'] == drug_class])
            profile[drug_class] = count
        
        drug_profiles.append(profile)
    
    drug_profile_df = pd.DataFrame(drug_profiles)
    output_file = output_dir / "7-drug_class_profile.csv"
    drug_profile_df.to_csv(output_file, index=False)
    print(f"✓ 输出：{output_file}")
    print(f"\n药物类别分布概览:")
    print(drug_profile_df.to_string(index=False))
    
    return drug_profile_df

def generate_summary_report(output_dir, results):
    """生成总结报告"""
    print("\n" + "="*60)
    print("📊 数据转换总结报告")
    print("="*60)
    
    report = f"""
数据转换完成！

✓ 生成的格式：
  0. 0-amr_sample_totals.csv
     - 用途：快速比较各样本耐药基因数量
     - 格式：样本 × Total_AMR_Genes
     - 适合工具：Excel 快速筛选、趋势图
  1. presence_absence_matrix.csv
     - 用途：机器学习、聚类分析、热力图可视化
     - 格式：样本 × 基因（0/1矩阵）
     - 适合工具：R ggplot2, Python seaborn, heatmap
  
  2. tidy_long_format.csv
     - 用途：ggplot2, tidyverse分析，统计检验
     - 格式：每行一个样本-基因关系
     - 适合工具：R ggplot2, dplyr, Python plotly
  
  3. phenotype_summary.csv
     - 用途：快速了解每个样本的耐药谱
     - 格式：样本 × 耐药类别统计
     - 适合工具：Excel, 描述性统计
  
  4. gene_cooccurrence_matrix.csv
     - 用途：基因关联分析、网络分析
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
  
  7. drug_class_profile.csv
     - 用途：样本分层、聚类、热力图
     - 格式：样本 × 药物类别（计数）
     - 适合工具：heatmap, 聚类分析

推荐分析流程：
  Step 1: 用 phenotype_summary.csv 做初步描述
  Step 2: 用 presence_absence_matrix.csv 进行聚类
  Step 3: 用 gene_cooccurrence_matrix.csv 分析基因关联
  Step 4: 用 network_data.json 在Cytoscape中可视化
  Step 5: 用 sample_resistance_metrics.csv 进行相关性分析
"""
    
    report_file = output_dir / "README_数据格式说明.txt"
    with open(report_file, 'w', encoding='utf-8') as f:
        f.write(report)
    
    print(report)
    print(f"\n📄 详细说明已保存到：{report_file}")


    print("\n✅ 所有转换完成！")


def main():
    if len(sys.argv) not in (3, 4):
        print(__doc__)
        sys.exit(1)

    input_csv = Path(sys.argv[1])
    output_dir = Path(sys.argv[2])
    flag_value = sys.argv[3] if len(sys.argv) == 4 else DEFAULT_FULL_OUTPUT_FLAG
    full_output = parse_full_output_flag(flag_value)

    if not input_csv.exists():
        print(f"❌ 输入文件不存在：{input_csv}")
        sys.exit(1)

    output_dir.mkdir(parents=True, exist_ok=True)

    df = load_amr_data(input_csv)
    if df.empty:
        print("⚠️ 警告：输入数据为空，仍将输出空模板文件。")

    totals_df, _ = export_sample_total_counts(df, output_dir)

    if not full_output:
        print("ℹ️ 根据参数“是否输出具体文件=否”，仅输出样本总数文件。")
        return

    results = {'sample_totals': totals_df}
    results['presence_absence'] = format_1_wide_gene_presence(df, output_dir)
    results['tidy_long'] = format_2_long_normalized(df, output_dir)
    results['phenotype_summary'] = format_3_phenotype_summary(df, output_dir)
    results['gene_cooccurrence'] = format_4_gene_cooccurrence(df, output_dir)
    results['network_json'] = format_5_json_network(df, output_dir)
    results['sample_metrics'] = format_6_sample_metrics(df, output_dir)
    results['drug_class_profile'] = format_7_drug_class_profile(df, output_dir)

    generate_summary_report(output_dir, results)
    print("\n✅ AMR 数据格式转换全部完成！")


if __name__ == "__main__":
    main()
