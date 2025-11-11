# AMRFinder 数据格式和分析方法速查表

## 📊 7种数据格式对比表

| 格式编号 | 文件名 | 数据形态 | 主要用途 | 推荐工具 | 典型分析 |
|---------|--------|--------|--------|---------|--------|
| **1** | presence_absence_matrix.csv | 样本×基因二值矩阵 | 聚类、机器学习 | R/Python | 层次聚类、PCA、heatmap |
| **2** | tidy_long_format.csv | 每行一个关系 | 统计检验、ggplot | R ggplot2 | ANOVA、t检验、分组比较 |
| **3** | phenotype_summary.csv | 样本×耐药类别计数 | 快速查阅、初步统计 | Excel、任何统计软件 | 描述性统计、异常值识别 |
| **4** | gene_cooccurrence_matrix.csv | 基因×基因共现计数 | 基因关联分析 | igraph、Cytoscape | 网络拓扑、中心性指标 |
| **5** | network_data.json | 图论格式(节点+边) | 交互式网络可视化 | Cytoscape、D3.js | 网络浏览、关键节点识别 |
| **6** | sample_resistance_metrics.csv | 样本×连续型指标 | 相关性、回归分析 | R/Python | Pearson相关、线性回归 |
| **7** | drug_class_profile.csv | 样本×药物类别计数 | 分层聚类、流行病学 | heatmap、聚类算法 | 样本分类、耐药谱分析 |

---

## 🎯 分析目标对应表

### 我想要... → 使用哪个文件？

| 分析目标 | 最佳文件 | 备选文件 | 推荐方法 | 输出示例 |
|---------|--------|--------|--------|---------|
| **📍 样本分组** | 1 或 7 | 3 | 聚类分析 (k-means/hierarchical) | 3个样本群体 |
| **🔗 基因关联** | 4 | 2 | 共现频率排序 | 前10个基因对 |
| **🧬 基因排序** | 2 或 3 | 4 | 按出现频数排序 | TOP 20基因 |
| **📈 相关性** | 6 | 2 | Pearson相关系数 | r=0.78, p<0.01 |
| **🌐 网络关系** | 5 | 4 | 图论分析 | 网络中心性指标 |
| **📊 热力图** | 1 或 7 | 3 | 聚类热力图 | 彩色矩阵 |
| **🎨 柱状图** | 3 或 7 | 6 | ggplot/matplotlib | 分组柱状图 |
| **📌 样本分类** | 6 或 7 | 3 | 多指标分层 | 低/中/高危 |
| **🔍 基因驱动** | 2 | 4 | 特征提取 | 关键基因列表 |
| **🏥 临床应用** | 6 | 3 | 风险评分 | MDR指数 |

---

## 💻 快速代码片段

### R语言

```R
# 加载数据
library(tidyverse)
library(pheatmap)

# 热力图
mat <- read.csv("1-presence_absence_matrix.csv", row.names=1) %>% as.matrix()
pheatmap(mat, main="耐药谱")

# 聚类
d <- dist(mat, method="jaccard")
hc <- hclust(d, method="average")
plot(hc)

# 长表格统计
df <- read.csv("2-tidy_long_format.csv")
df %>% group_by(Drug_Class) %>% summarise(n=n())
```

### Python

```python
import pandas as pd
import seaborn as sns
import matplotlib.pyplot as plt
from sklearn.cluster import AgglomerativeClustering
from scipy.spatial.distance import pdist, squareform

# 加载
df = pd.read_csv("1-presence_absence_matrix.csv", index_col=0)

# 热力图
sns.heatmap(df, cmap="coolwarm")
plt.savefig("heatmap.png")

# 聚类
from scipy.cluster.hierarchy import dendrogram, linkage
distances = pdist(df.values, metric='jaccard')
Z = linkage(distances, method='average')
dendrogram(Z, labels=df.index)
plt.savefig("dendrogram.png")
```

### 在线工具

| 工具 | 输入格式 | URL |
|-----|--------|-----|
| Heatmap.2 Server | CSV矩阵 | http://bioinformatics.uconn.edu/heatmap/ |
| Cytoscape Web | JSON网络 | https://cytoscape.org/cytoscape-web/ |
| ClustVis | 矩阵 | http://biit.cs.ut.ee/clustvis/ |
| MetaboAnalyst | 矩阵 | https://www.metaboanalyst.ca/ |

---

## 📋 分析清单

### Step 1: 数据探索 (Data Exploration)
- [ ] 查看 `3-phenotype_summary.csv` 的基本统计
- [ ] 检查样本耐药基因数的分布 (min/max/mean)
- [ ] 识别特殊样本 (异常值)

### Step 2: 可视化 (Visualization)
- [ ] 绘制热力图 (1-presence_absence_matrix.csv)
- [ ] 绘制条形图 (3-phenotype_summary.csv)
- [ ] 绘制聚类树 (1-presence_absence_matrix.csv)

### Step 3: 关键发现 (Key Finding)
- [ ] 识别高频基因 (analysis_4_gene_frequency_profile.csv)
- [ ] 发现基因共现模式 (analysis_2_gene_associations.csv)
- [ ] 样本分层 (analysis_3_resistance_stratification.csv)

### Step 4: 统计验证 (Statistical Validation)
- [ ] 进行相关性分析 (6-sample_resistance_metrics.csv)
- [ ] 比较样本群体间差异
- [ ] 计算p值和效应量

### Step 5: 网络分析 (Network Analysis)
- [ ] 导入网络数据到Cytoscape (5-network_data.json)
- [ ] 计算网络拓扑指标
- [ ] 识别关键节点 (hub genes)

### Step 6: 临床应用 (Clinical Application)
- [ ] 建立风险评分模型
- [ ] 与临床表型相关联
- [ ] 制作决策支持工具

---

## 🔄 数据流转图

```
原始CSV
  ↓
格式1: 二值矩阵 ──→ 聚类分析 ──→ 样本群体
  ↓
格式2: 长表格 ──→ 统计检验 ──→ 显著性
  ↓
格式3: 快览表 ──→ 初步统计 ──→ 描述指标
  ↓
格式4: 共现矩阵 ──→ 基因关联 ──→ 基因组合
  ↓
格式5: 网络JSON ──→ Cytoscape ──→ 网络可视化
  ↓
格式6: 连续指标 ──→ 回归分析 ──→ 预测模型
  ↓
格式7: 药物矩阵 ──→ 分层聚类 ──→ 临床分类
```

---

## 📚 关键指标解释

### 耐药相关指标
| 指标 | 定义 | 解释 | 范围 |
|-----|-----|-----|-----|
| Total_ARGs | 耐药基因总数 | 基因积累水平 | 10-25 |
| Core_ARGs | 核心基因数 | 物种特异性 | 通常>50% |
| Plus_ARGs | 扩展基因数 | 应激/毒力 | 通常<50% |
| Unique_Drug_Classes | 药物类别数 | 多药耐药范围 | 3-8 |
| MultiDrug_Resistance_Index | MDR指数 | 相对耐药强度 | 0.8-2.0 |
| Efflux_Pump_Genes | 外排泵基因数 | 耐药机制 | 2-4 |

### 基因质量指标
| 指标 | 定义 | 高质量标准 |
|-----|-----|----------|
| Coverage | 参考基因覆盖度 | ≥90% |
| Identity | 序列同源性 | ≥99% |
| Method | 识别方法 | EXACTP/BLASTP |

---

## ⚙️ 高级定制选项

### 如何修改聚类参数？
编辑 `3-format_analysis_examples.py` 的 `analyze_clustering` 函数：
```python
# 修改聚类方法
linkage_method = 'ward'  # 改为 'complete', 'single', 等

# 修改聚类数
t = 5  # 改为所需的簇数

# 修改距离度量
metric = 'euclidean'  # 改为 'cosine', 'hamming', 等
```

### 如何修改共现阈值？
编辑 `3-format_analysis_examples.py` 的 `analyze_gene_associations` 函数：
```python
# 修改共现计数阈值
if cooccurrence_count >= 5:  # 改为所需阈值
```

### 如何增加新的分析类型？
在 `3-format_analysis_examples.py` 中添加新函数，并在 `main()` 中调用。

---

## 🆘 常见问题排查

| 问题 | 原因 | 解决方案 |
|-----|-----|--------|
| 转换报错 `No module named pandas` | Python缺少依赖 | `pip install pandas numpy scipy` |
| 输出文件为空 | 输入CSV格式不匹配 | 检查列名是否与代码一致 |
| 聚类结果不合理 | 聚类参数不适合 | 尝试不同的方法和距离度量 |
| Cytoscape打开JSON失败 | JSON格式错误 | 用在线JSON验证器检查 |
| 热力图太拥挤 | 样本/基因过多 | 用聚类结果进行子集分析 |

---

## 📞 获取帮助

- 查看SUMMARY.txt获取详细说明
- 查看各个Python脚本的docstring
- 参考visualization_examples.R/py的注释
- 参考READme_数据格式说明.txt

---

## 📅 版本信息

- 创建时间: 2025-11-10
- 脚本版本: 1.0
- 支持格式: 7种数据格式
- 包含分析: 5项深度分析 + 5项格式转换
