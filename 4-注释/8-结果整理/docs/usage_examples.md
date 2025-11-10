# AMRFinder 数据分析实战示例

## 目录
1. [快速开始](#快速开始)
2. [分析示例](#分析示例)
3. [可视化示例](#可视化示例)
4. [常见问题](#常见问题)

---

## 快速开始

### 最小化使用（5分钟快速了解数据）

```bash
# 1. 运行格式转换
python3 2-AMR_format_conversion.py /path/to/All_Samples_抗生素耐药.csv ./output

# 2. 用Excel打开快览表查看
open output/3-phenotype_summary.csv

# 3. 就这样！您已经有了7种分析格式
ls output/*.csv
```

**输出内容一览：**
- 可以立即看到每个样本的耐药基因数、药物类别等
- 样本数量、基因覆盖度等基本统计

---

## 分析示例

### 示例1: 我想找出最耐药的样本

```python
import pandas as pd

# 加载快览表
df = pd.read_csv("output/3-phenotype_summary.csv")

# 按耐药基因数排序
top_resistant = df.nlargest(10, 'Total_ARGs')[['Sample', 'Total_ARGs', 'Core_ARGs', 'Plus_ARGs']]
print("最耐药的10个样本：")
print(top_resistant)

# 输出
# Sample        Total_ARGs  Core_ARGs  Plus_ARGs
# DRR033191     21          18         3
# DRR033194     19          17         2
# DRR033183     18          16         2
# ...
```

### 示例2: 我想找出所有携带碳青霉烯耐药基因的样本

```python
import pandas as pd

# 加载长表格
df = pd.read_csv("output/2-tidy_long_format.csv")

# 筛选碳青霉烯耐药基因
carbapenem_samples = df[df['Drug_Subclass'].str.contains('CARBAPENEM', na=False)]

# 获取样本列表
samples = carbapenem_samples['Sample_ID'].unique()
print(f"携带碳青霉烯耐药基因的样本：{len(samples)}/{df['Sample_ID'].nunique()}")
print("样本列表：")
print(sorted(samples))

# 输出
# 携带碳青霉烯耐药基因的样本：87/87  (即100%)
```

### 示例3: 我想了解哪些基因最常见

```python
import pandas as pd

# 加载分析结果
df = pd.read_csv("output/analyses/analysis_4_gene_frequency_profile.csv")

# 按流行度排序
common_genes = df[df['Prevalence_%'] >= 50]
print("流行度≥50%的基因：")
for idx, row in common_genes.iterrows():
    print(f"  {row['Gene_Symbol']:15s} {row['Prevalence_%']:5.1f}% "
          f"({row['Sample_Count']}/{df['Sample_ID'].nunique()} samples) - {row['Drug_Class']}")

# 输出示例
#   blaOXA-51       95.4% (83/87 samples) - BETA-LACTAM
#   aph(6)-Id       93.1% (81/87 samples) - AMINOGLYCOSIDE
#   tet(B)          86.2% (75/87 samples) - TETRACYCLINE
#   ...
```

### 示例4: 我想知道哪些基因组合最常见

```python
import pandas as pd

# 加载基因关联分析
df = pd.read_csv("output/analyses/analysis_2_gene_associations.csv")

# 显示最强关联（可能形成耐药平台）
print("最强的基因关联（耐药平台）：")
for idx, row in df.head(15).iterrows():
    print(f"  {row['Gene_1']:15s} + {row['Gene_2']:15s} "
          f"共现{row['CoOccurrence_Count']:2d}个样本 ({row['Association_Strength']})")

# 输出示例
#   aph(3'')-Ib     + aph(6)-Id           共现81个样本 (Strong)
#   blaOXA-51       + blaOXA-23           共现75个样本 (Strong)
#   tet(B)          + adeC                共现68个样本 (Strong)
#   ...
```

### 示例5: 我想对样本进行分类（用于临床应用）

```python
import pandas as pd

# 加载分层结果
df = pd.read_csv("output/analyses/analysis_3_resistance_stratification.csv")

# 按分类统计
print("\n样本耐药强度分布：")
for category in ['Extreme_MDR', 'Severe_MDR', 'Moderate_MDR', 'Limited_Resistance']:
    count = len(df[df['Category'] == category])
    pct = count / len(df) * 100
    samples = df[df['Category'] == category]['Sample'].tolist()
    print(f"\n{category}:")
    print(f"  数量: {count} ({pct:.1f}%)")
    print(f"  样本: {', '.join(samples)}")

# 输出示例
# Extreme_MDR:
#   数量: 42 (48.3%)
#   样本: DRR033191, DRR033194, DRR033183, ...
```

### 示例6: 我想做样本聚类

```python
import pandas as pd
from sklearn.cluster import AgglomerativeClustering
from scipy.spatial.distance import pdist, squareform

# 加载矩阵
matrix = pd.read_csv("output/1-presence_absence_matrix.csv", index_col=0)

# 计算距离
distances = pdist(matrix.values, metric='jaccard')
dist_matrix = squareform(distances)

# 聚类
clustering = AgglomerativeClustering(n_clusters=3, linkage='average').fit(matrix)
clusters = clustering.labels_

# 显示聚类结果
result = pd.DataFrame({
    'Sample': matrix.index,
    'Cluster': clusters
})

print("聚类结果：")
for cluster_id in sorted(set(clusters)):
    samples = result[result['Cluster'] == cluster_id]['Sample'].tolist()
    print(f"\n聚类{cluster_id}: {len(samples)}个样本")
    print(f"  {samples}")

# 输出示例
# 聚类0: 28个样本
#   [DRR033181, DRR033182, ...]
# 聚类1: 35个样本
#   [...]
# 聚类2: 24个样本
#   [...]
```

### 示例7: 我想计算耐药相关性

```python
import pandas as pd
from scipy.stats import pearsonr, spearmanr

# 加载指标数据
metrics = pd.read_csv("output/6-sample_resistance_metrics.csv")

# 计算相关性
r_pearson, p_pearson = pearsonr(metrics['Total_ARGs'], metrics['Unique_Drug_Classes'])
r_spearman, p_spearman = spearmanr(metrics['Total_ARGs'], metrics['Unique_Drug_Classes'])

print(f"耐药基因数 vs 药物类别数的相关性：")
print(f"  Pearson: r={r_pearson:.3f}, p={p_pearson:.2e}")
print(f"  Spearman: r={r_spearman:.3f}, p={p_spearman:.2e}")

# 输出示例
#   Pearson: r=0.856, p=1.23e-23
#   Spearman: r=0.842, p=3.45e-22
# （高度正相关）
```

---

## 可视化示例

### 热力图：样本×基因

```R
library(pheatmap)

# 加载数据
mat <- read.csv("output/1-presence_absence_matrix.csv", row.names=1)
mat <- as.matrix(mat)

# 绘制热力图
pheatmap(mat,
         main="鲍曼不动杆菌耐药基因分布热力图",
         color=colorRampPalette(c("white", "lightblue", "darkblue"))(50),
         breaks=seq(0, 1, length.out=51),
         cluster_rows=TRUE,
         cluster_cols=TRUE,
         fontsize=8,
         filename="heatmap_sample_gene.png",
         height=12, width=16)
```

### 条形图：样本的耐药基因数

```R
library(ggplot2)

# 加载数据
df <- read.csv("output/3-phenotype_summary.csv")
df$Sample <- factor(df$Sample, levels=df$Sample[order(df$Total_ARGs)])

# 绘制条形图
ggplot(df, aes(x=Sample, y=Total_ARGs, fill=BETA_LACTAM)) +
  geom_col() +
  coord_flip() +
  labs(title="样本耐药基因数分布",
       x="样本",
       y="耐药基因数") +
  theme_minimal() +
  theme(axis.text.y=element_text(size=6))

ggsave("barplot_sample_arg_count.png", width=10, height=12, dpi=300)
```

### 散点图：基因数 vs 药物类别

```python
import matplotlib.pyplot as plt
import pandas as pd

df = pd.read_csv("output/6-sample_resistance_metrics.csv")

plt.figure(figsize=(10, 8))
plt.scatter(df['Total_ARGs'], df['Unique_Drug_Classes'], 
           s=100, alpha=0.6, c=df['Efflux_Pump_Genes'], 
           cmap='viridis')

# 添加样本标签
for idx, row in df.iterrows():
    plt.annotate(row['Sample'], 
                (row['Total_ARGs'], row['Unique_Drug_Classes']),
                fontsize=7, alpha=0.7)

plt.xlabel('耐药基因总数')
plt.ylabel('药物类别数')
plt.title('多药耐药相关性分析')
plt.colorbar(label='外排泵基因数')
plt.grid(alpha=0.3)
plt.tight_layout()
plt.savefig("scatter_mdr_correlation.png", dpi=300)
plt.close()
```

### 网络可视化：在Cytoscape中

```
1. 打开Cytoscape (https://cytoscape.org/)
2. File → Import → Network from File
3. 选择 output/5-network_data.json
4. 执行Layout → Prefuse Force Directed Layout
5. 调整节点大小（按degree）和颜色（按drug_class）
```

---

## 常见问题

### Q: 如何快速查看某个样本的耐药基因？

A:
```python
import pandas as pd

sample_name = "DRR033191"
df = pd.read_csv("output/2-tidy_long_format.csv")
sample_genes = df[df['Sample_ID'] == sample_name]

print(f"{sample_name}的耐药基因（{len(sample_genes)}个）：")
for _, row in sample_genes.iterrows():
    print(f"  {row['Gene_Symbol']:15s} - {row['Drug_Subclass']:20s} ({row['Identity_%']:.1f}% identity)")
```

### Q: 如何比较两个样本之间的相似性？

A:
```python
import pandas as pd
from scipy.spatial.distance import jaccard

# 加载矩阵
mat = pd.read_csv("output/1-presence_absence_matrix.csv", index_col=0)

# 获取两个样本
sample1 = "DRR033191"
sample2 = "DRR033192"

# 计算Jaccard距离（0为完全相同，1为完全不同）
distance = jaccard(mat.loc[sample1], mat.loc[sample2])
similarity = 1 - distance

print(f"{sample1} vs {sample2}:")
print(f"  相似度: {similarity:.2%}")
print(f"  距离: {distance:.3f}")
```

### Q: 如何筛选特定类型的耐药基因？

A:
```python
import pandas as pd

df = pd.read_csv("output/2-tidy_long_format.csv")

# 筛选碳青霉烯耐药基因
carbapenem = df[df['Drug_Subclass'] == 'CARBAPENEM']
print(f"碳青霉烯耐药基因：{carbapenem['Gene_Symbol'].unique()}")

# 筛选外排泵基因
efflux_patterns = ['adeC', 'amvA', 'tet(B)', 'cxpE']
efflux = df[df['Gene_Symbol'].isin(efflux_patterns)]
print(f"外排泵基因：{efflux['Gene_Symbol'].unique()}")
```

### Q: 如何识别某个基因在哪些样本中出现？

A:
```python
import pandas as pd

gene_name = "blaOXA-51"
mat = pd.read_csv("output/1-presence_absence_matrix.csv", index_col=0)

if gene_name in mat.columns:
    samples_with_gene = mat[mat[gene_name] == 1].index.tolist()
    print(f"{gene_name}出现在{len(samples_with_gene)}个样本中：")
    print(samples_with_gene)
else:
    print(f"基因{gene_name}不在矩阵中")
```

### Q: 如何导出报告用的表格？

A:
```python
import pandas as pd

# 加载分析结果
summary = pd.read_csv("output/3-phenotype_summary.csv")
genes = pd.read_csv("output/analyses/analysis_4_gene_frequency_profile.csv")
clusters = pd.read_csv("output/analyses/analysis_1_clustering_result.csv")

# 合并生成报告
with pd.ExcelWriter('report.xlsx') as writer:
    summary.to_excel(writer, sheet_name='样本汇总')
    genes.to_excel(writer, sheet_name='基因频率')
    clusters.to_excel(writer, sheet_name='聚类结果')

print("报告已保存到 report.xlsx")
```

---

## 推荐的分析流程

### 快速浏览模式（15分钟）
1. 打开 `3-phenotype_summary.csv` 了解基本情况
2. 查看 `analysis_4_gene_frequency_profile.csv` 的Top基因
3. 查看 `analysis_3_resistance_stratification.csv` 的分类

### 标准分析模式（1小时）
1. 用 `1-presence_absence_matrix.csv` 做热力图
2. 用 `analysis_1_clustering_result.csv` 了解样本分群
3. 用 `analysis_2_gene_associations.csv` 了解基因关联
4. 用 `6-sample_resistance_metrics.csv` 做相关性分析

### 深度研究模式（3小时+）
1. 完整聚类分析和去杂交叉验证
2. 基因组学分析（比对、进化、系统发育）
3. 机器学习分类预测
4. 网络拓扑深度分析
5. 与表型/临床数据的多变量关联

---

## 更多资源

- 📖 查看 `SUMMARY.txt` 获取详细说明
- 📚 查看 `format_reference.md` 获取格式速查表
- 🔧 查看各个脚本的注释获取技术细节
- 💬 查看 `visualization_examples.R/py` 获取更多可视化示例

---

**最后更新**: 2025-11-10
**维护者**: 数据分析团队
