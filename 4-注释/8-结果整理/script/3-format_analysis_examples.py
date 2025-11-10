#!/usr/bin/env python3
"""
AMRFinder 数据分析示例
展示如何使用不同格式进行具体的数据分析

包含的分析：
1. 样本聚类 - 基于耐药谱
2. 基因关联分析 - 共现基因对
3. 样本分类 - 耐药强度分层
4. 热力图可视化 - 基因分布
5. 相关性分析 - 耐药指数相关
"""

import pandas as pd
import numpy as np
from pathlib import Path
from scipy.spatial.distance import pdist, squareform
from scipy.cluster.hierarchy import dendrogram, linkage, fcluster
import json
import sys

def analyze_clustering(presence_matrix_file, output_dir):
    """1. 基于presence/absence矩阵的聚类分析"""
    print("\n" + "="*60)
    print("📊 分析1：样本聚类 - 基于耐药谱相似性")
    print("="*60)
    
    df = pd.read_csv(presence_matrix_file, index_col=0)
    
    # 计算距离矩阵
    distances = pdist(df.values, metric='jaccard')
    dist_matrix = squareform(distances)
    
    # 系统聚类
    Z = linkage(distances, method='average')
    clusters = fcluster(Z, t=3, criterion='maxclust')
    
    # 输出聚类结果
    cluster_result = pd.DataFrame({
        'Sample': df.index,
        'Cluster': clusters,
        'Total_Genes': df.sum(axis=1)
    }).sort_values('Cluster')
    
    output_file = output_dir / "analysis_1_clustering_result.csv"
    cluster_result.to_csv(output_file, index=False)
    print(f"✓ 聚类结果：{output_file}")
    print("\n聚类分配（样本→组群）：")
    for cluster_id in sorted(clusters):
        samples = cluster_result[cluster_result['Cluster'] == cluster_id]['Sample'].tolist()
        print(f"  Group {cluster_id}: {samples}")
    
    return cluster_result

def analyze_gene_associations(cooccurrence_file, output_dir):
    """2. 基因共现关联分析"""
    print("\n" + "="*60)
    print("📊 分析2：基因关联 - 最常见的共现模式")
    print("="*60)
    
    df = pd.read_csv(cooccurrence_file, index_col=0)
    
    # 找出高共现基因对（共现≥3个样本）
    associations = []
    for i, gene1 in enumerate(df.index):
        for j, gene2 in enumerate(df.columns):
            if i < j:  # 只取上三角
                cooccurrence_count = df.loc[gene1, gene2]
                if cooccurrence_count >= 3:
                    associations.append({
                        'Gene_1': gene1,
                        'Gene_2': gene2,
                        'CoOccurrence_Count': cooccurrence_count,
                        'Association_Strength': 'Strong' if cooccurrence_count >= 5 else 'Moderate'
                    })
    
    assoc_df = pd.DataFrame(associations).sort_values('CoOccurrence_Count', ascending=False)
    
    output_file = output_dir / "analysis_2_gene_associations.csv"
    assoc_df.to_csv(output_file, index=False)
    print(f"✓ 关联结果：{output_file}")
    print(f"\n强关联基因对（≥5个样本共现）：")
    for _, row in assoc_df[assoc_df['Association_Strength'] == 'Strong'].head(10).iterrows():
        print(f"  {row['Gene_1']} ←→ {row['Gene_2']}: {row['CoOccurrence_Count']} 样本")

def analyze_resistance_stratification(metrics_file, output_dir):
    """3. 耐药强度分层"""
    print("\n" + "="*60)
    print("📊 分析3：样本分层 - 耐药强度分类")
    print("="*60)
    
    df = pd.read_csv(metrics_file)
    
    # 基于多个指标进行分层
    # 使用Total_ARGs和Drug_Classes作为主要指标
    df['Resistance_Level'] = pd.cut(
        df['Total_ARGs'], 
        bins=[0, 10, 15, 20, 1000],
        labels=['Low', 'Moderate', 'High', 'Extreme']
    )
    
    df['MDR_Category'] = pd.cut(
        df['Unique_Drug_Classes'],
        bins=[0, 2, 4, 6, 10],
        labels=['Few_Classes', 'Moderate_Classes', 'Many_Classes', 'Comprehensive']
    )
    
    # 创建综合分类
    stratification = []
    for _, row in df.iterrows():
        if row['Unique_Drug_Classes'] >= 5 and row['Total_ARGs'] >= 15:
            category = 'Extreme_MDR'
        elif row['Unique_Drug_Classes'] >= 4 and row['Total_ARGs'] >= 12:
            category = 'Severe_MDR'
        elif row['Unique_Drug_Classes'] >= 3 and row['Total_ARGs'] >= 10:
            category = 'Moderate_MDR'
        else:
            category = 'Limited_Resistance'
        
        stratification.append({
            'Sample': row['Sample'],
            'Total_ARGs': row['Total_ARGs'],
            'Drug_Classes': row['Unique_Drug_Classes'],
            'Category': category
        })
    
    strat_df = pd.DataFrame(stratification)
    output_file = output_dir / "analysis_3_resistance_stratification.csv"
    strat_df.to_csv(output_file, index=False)
    print(f"✓ 分层结果：{output_file}")
    print("\n分类统计：")
    for category in ['Extreme_MDR', 'Severe_MDR', 'Moderate_MDR', 'Limited_Resistance']:
        count = len(strat_df[strat_df['Category'] == category])
        samples = strat_df[strat_df['Category'] == category]['Sample'].tolist()
        print(f"  {category}: {count} 个样本")
        if samples:
            print(f"    示例：{', '.join(samples[:3])}")

def analyze_gene_frequency_profile(tidy_long_file, output_dir):
    """4. 基因频率谱"""
    print("\n" + "="*60)
    print("📊 分析4：基因频率谱 - 哪些基因最常见？")
    print("="*60)
    
    df = pd.read_csv(tidy_long_file)
    
    # 统计每个基因出现的样本数
    gene_freq = df.groupby('Gene_Symbol').agg({
        'Sample_ID': 'nunique',
        'Gene_Name': 'first',
        'Drug_Class': 'first'
    }).rename(columns={'Sample_ID': 'Sample_Count'}).reset_index()
    
    gene_freq = gene_freq.sort_values('Sample_Count', ascending=False)
    gene_freq['Prevalence_%'] = (gene_freq['Sample_Count'] / df['Sample_ID'].nunique() * 100).round(1)
    
    output_file = output_dir / "analysis_4_gene_frequency_profile.csv"
    gene_freq.to_csv(output_file, index=False)
    print(f"✓ 频率谱：{output_file}")
    print(f"\n高频基因（出现在≥70%样本中）：")
    for _, row in gene_freq[gene_freq['Prevalence_%'] >= 70].iterrows():
        print(f"  {row['Gene_Symbol']}: {row['Sample_Count']}/{df['Sample_ID'].nunique()} 样本 ({row['Prevalence_%']}%)")

def analyze_drug_class_patterns(drug_profile_file, output_dir):
    """5. 药物类别耐药模式"""
    print("\n" + "="*60)
    print("📊 分析5：药物类别耐药模式")
    print("="*60)
    
    df = pd.read_csv(drug_profile_file)
    
    # 计算每个药物类别的统计
    drug_stats = []
    for col in df.columns[1:]:  # 跳过Sample列
        values = df[col]
        drug_stats.append({
            'Drug_Class': col,
            'Mean_Count': values.mean(),
            'Max_Count': values.max(),
            'Min_Count': values.min(),
            'Samples_With_Resistance': (values > 0).sum(),
            'Prevalence_%': ((values > 0).sum() / len(df) * 100)
        })
    
    stats_df = pd.DataFrame(drug_stats).sort_values('Prevalence_%', ascending=False)
    
    output_file = output_dir / "analysis_5_drug_class_patterns.csv"
    stats_df.to_csv(output_file, index=False)
    print(f"✓ 药物模式：{output_file}")
    print("\n耐药流行度（排序）：")
    for _, row in stats_df.iterrows():
        print(f"  {row['Drug_Class']:20s}: {row['Prevalence_%']:5.1f}% 样本 (平均{row['Mean_Count']:.1f}个基因)")

def generate_visualization_code(output_dir):
    """6. 生成可视化代码模板"""
    print("\n" + "="*60)
    print("📊 分析6：可视化代码模板")
    print("="*60)
    
    r_code = '''# ==================== R语言可视化示例 ====================
# 需要安装：install.packages(c("tidyverse", "ggplot2", "pheatmap", "igraph"))

library(tidyverse)
library(ggplot2)
library(pheatmap)

# 1. 热力图 - 样本×基因
presence_df <- read.csv("1-presence_absence_matrix.csv", row.names=1)
pheatmap(t(presence_df), 
         main="样本×基因耐药谱",
         cluster_cols=TRUE, 
         cluster_rows=TRUE,
         color=colorRampPalette(c("white", "red"))(50))

# 2. 条形图 - 样本的耐药基因数
metrics_df <- read.csv("6-sample_resistance_metrics.csv")
ggplot(metrics_df, aes(x=reorder(Sample, Total_ARGs), y=Total_ARGs, fill=Unique_Drug_Classes)) +
  geom_col() +
  coord_flip() +
  labs(title="样本耐药基因数", x="Sample", y="耐药基因数") +
  theme_minimal()

# 3. 散点图 - 基因数 vs 药物类别
ggplot(metrics_df, aes(x=Total_ARGs, y=Unique_Drug_Classes, size=MultiDrug_Resistance_Index)) +
  geom_point(alpha=0.6, color="steelblue") +
  geom_label_repel(aes(label=Sample)) +
  labs(title="多药耐药相关性", x="耐药基因总数", y="药物类别数") +
  theme_minimal()

# 4. 饼图 - 药物类别分布
drug_summary <- colSums(read.csv("7-drug_class_profile.csv", row.names=1))
pie(drug_summary, main="耐药基因在不同药物类别的分布")
'''
    
    python_code = '''# ==================== Python可视化示例 ====================
# 需要安装：pip install matplotlib seaborn pandas numpy

import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
import seaborn as sns

# 1. 热力图
presence_df = pd.read_csv("1-presence_absence_matrix.csv", index_col=0)
plt.figure(figsize=(15, 8))
sns.heatmap(presence_df, cmap="RdYlBu", cbar_kws={'label': 'Gene Present'})
plt.title("样本×基因耐药谱热力图")
plt.savefig("heatmap_sample_gene.png", dpi=300, bbox_inches='tight')
plt.close()

# 2. 条形图
metrics_df = pd.read_csv("6-sample_resistance_metrics.csv")
plt.figure(figsize=(12, 8))
metrics_df_sorted = metrics_df.sort_values('Total_ARGs')
plt.barh(metrics_df_sorted['Sample'], metrics_df_sorted['Total_ARGs'], 
         color=plt.cm.viridis(metrics_df_sorted['Unique_Drug_Classes']/metrics_df_sorted['Unique_Drug_Classes'].max()))
plt.xlabel('耐药基因总数')
plt.title('样本耐药基因数分布')
plt.tight_layout()
plt.savefig("barplot_arg_count.png", dpi=300, bbox_inches='tight')
plt.close()

# 3. 散点图
plt.figure(figsize=(10, 8))
scatter = plt.scatter(metrics_df['Total_ARGs'], 
                      metrics_df['Unique_Drug_Classes'],
                      s=metrics_df['Efflux_Pump_Genes']*30,
                      alpha=0.6, c=metrics_df['Avg_Coverage_%'],
                      cmap='coolwarm')
for idx, row in metrics_df.iterrows():
    plt.annotate(row['Sample'], (row['Total_ARGs'], row['Unique_Drug_Classes']), 
                fontsize=8, alpha=0.7)
plt.xlabel('耐药基因总数')
plt.ylabel('药物类别数')
plt.title('多药耐药相关性分析')
cbar = plt.colorbar(scatter)
cbar.set_label('平均覆盖度(%)')
plt.grid(alpha=0.3)
plt.tight_layout()
plt.savefig("scatter_mdr_analysis.png", dpi=300, bbox_inches='tight')
plt.close()
'''
    
    # 保存代码
    r_file = output_dir / "visualization_examples.R"
    with open(r_file, 'w', encoding='utf-8') as f:
        f.write(r_code)
    
    python_file = output_dir / "visualization_examples.py"
    with open(python_file, 'w', encoding='utf-8') as f:
        f.write(python_code)
    
    print(f"✓ R可视化代码：{r_file}")
    print(f"✓ Python可视化代码：{python_file}")

def main():
    if len(sys.argv) < 2:
        print("用法：python3 3-format_analysis_examples.py <output_dir_from_step2>")
        print("示例：python3 3-format_analysis_examples.py ./amr_output")
        sys.exit(1)
    
    work_dir = Path(sys.argv[1])
    output_dir = work_dir / "analyses"
    output_dir.mkdir(exist_ok=True)
    
    print("🔍 执行5项分析...\n")
    
    # 运行各种分析
    analyze_clustering(
        work_dir / "1-presence_absence_matrix.csv",
        output_dir
    )
    
    analyze_gene_associations(
        work_dir / "4-gene_cooccurrence_matrix.csv",
        output_dir
    )
    
    analyze_resistance_stratification(
        work_dir / "6-sample_resistance_metrics.csv",
        output_dir
    )
    
    analyze_gene_frequency_profile(
        work_dir / "2-tidy_long_format.csv",
        output_dir
    )
    
    analyze_drug_class_patterns(
        work_dir / "7-drug_class_profile.csv",
        output_dir
    )
    
    generate_visualization_code(output_dir)
    
    print("\n" + "="*60)
    print("✅ 所有分析完成！")
    print("="*60)
    print(f"\n📁 结果保存在：{output_dir}")
    print("\n📊 生成的分析文件：")
    print("  - analysis_1_clustering_result.csv (聚类分组)")
    print("  - analysis_2_gene_associations.csv (基因共现)")
    print("  - analysis_3_resistance_stratification.csv (耐药强度分类)")
    print("  - analysis_4_gene_frequency_profile.csv (基因频率)")
    print("  - analysis_5_drug_class_patterns.csv (药物类别模式)")
    print("  - visualization_examples.R/py (可视化代码)")

if __name__ == "__main__":
    main()
