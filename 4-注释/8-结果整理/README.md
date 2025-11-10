# 📊 AMRFinder 数据分析系统 - 完整指南

## 系统概述

这是一个为AMRFinder结果设计的完整数据分析和可视化系统，包括：
- ✅ 7种数据格式转换
- ✅ 5项深度分析
- ✅ 多种可视化选项
- ✅ 完整的文档和示例

```
原始CSV数据
    ↓
[格式转换模块] ← 2-AMR_format_conversion.py
    ↓
7种数据格式 + 7项分析报告
    ↓
[分析模块] ← 3-format_analysis_examples.py
    ↓
5项深度分析结果
    ↓
[可视化] ← R/Python/在线工具
    ↓
科研论文/报告
```

---

## 📁 文件结构和说明

```
8-结果整理/
├── script/
│   ├── 0-quick_start.sh ..................... [启动脚本] 一键执行全流程
│   ├── 1.sh ................................. [旧脚本] 可删除
│   ├── 2-AMR_format_conversion.py ........... [核心] 7种格式转换
│   └── 3-format_analysis_examples.py ........ [核心] 5项深度分析
│
├── docs/
│   ├── format_reference.md .................. [速查表] 7×7对比表、代码片段
│   ├── usage_examples.md .................... [实战] 7个具体分析示例
│   └── README.md ............................ [本文件] 系统总体指南
│
└── output/ (运行后生成)
    ├── [格式文件1-7].csv ................... 7种数据格式
    ├── README_数据格式说明.txt ........... 详细说明
    ├── SUMMARY.txt ........................ 总结报告
    ├── analyses/
    │   ├── analysis_1_clustering_result.csv
    │   ├── analysis_2_gene_associations.csv
    │   ├── analysis_3_resistance_stratification.csv
    │   ├── analysis_4_gene_frequency_profile.csv
    │   ├── analysis_5_drug_class_patterns.csv
    │   ├── visualization_examples.R
    │   └── visualization_examples.py
    └── heatmap.png, plot.png ... (运行可视化脚本后)
```

---

## 🚀 使用方法

### 方法1: 一键启动（推荐）

```bash
cd /mnt/f/OneDrive/文档（科研）/脚本/Download/13-A.baumannii/4-注释/8-结果整理/script

# 运行完整流程
bash 0-quick_start.sh /path/to/All_Samples_抗生素耐药.csv ./output

# 或使用默认路径（自动查找）
bash 0-quick_start.sh
```

**输出**：
- 7个CSV格式文件 + 5个分析结果 + 代码模板 + 总结报告
- 大约3-5分钟完成

### 方法2: 分步执行

```bash
# Step 1: 格式转换
python3 2-AMR_format_conversion.py input.csv ./output

# Step 2: 数据分析
python3 3-format_analysis_examples.py ./output

# Step 3: 制作可视化
Rscript output/analyses/visualization_examples.R
# 或
python3 output/analyses/visualization_examples.py
```

### 方法3: 编程式调用

```python
import sys
sys.path.insert(0, '/path/to/script')

from format_conversion import load_amr_data, format_1_wide_gene_presence
import pandas as pd

# 加载数据
df = load_amr_data('input.csv')

# 执行格式转换
presence_matrix = format_1_wide_gene_presence(df, Path('./output'))
```

---

## 📊 7种数据格式详解

### 1️⃣ **Presence/Absence Matrix** (二值矩阵)
```
文件: 1-presence_absence_matrix.csv
结构: 行=样本，列=基因，值=0/1
用途: 聚类、机器学习、热力图
```

```csv
Sample,blaOXA-51,aph(6)-Id,tet(B),...
DRR033181,1,1,1,...
DRR033182,1,1,0,...
```

**推荐分析**:
- 层次聚类
- PCA降维
- 随机森林分类

### 2️⃣ **Tidy Long Format** (规范化长表格)
```
文件: 2-tidy_long_format.csv
结构: 每行一个样本-基因关系
用途: ggplot2、统计检验、分组分析
```

```csv
Sample_ID,Gene_Symbol,Drug_Class,Identity_%,Coverage_%
DRR033181,blaOXA-51,BETA-LACTAM,100.0,100.0
DRR033181,aph(6)-Id,AMINOGLYCOSIDE,100.0,100.0
```

**推荐分析**:
- ANOVA方差分析
- t检验
- 非参数检验

### 3️⃣ **Phenotype Summary** (快览表)
```
文件: 3-phenotype_summary.csv
结构: 行=样本，列=各耐药类别的基因数
用途: 初步统计、快速查阅、描述性统计
```

```csv
Sample,Total_ARGs,Core_ARGs,BETA_LACTAM,AMINOGLYCOSIDE,...
DRR033181,12,11,2,3,...
DRR033182,13,12,2,4,...
```

**推荐分析**:
- 描述性统计
- 样本排序筛选
- 初步异常值检测

### 4️⃣ **Gene Cooccurrence Matrix** (基因共现矩阵)
```
文件: 4-gene_cooccurrence_matrix.csv
结构: 行=基因，列=基因，值=共现样本数
用途: 基因关联分析、网络分析
```

```csv
Gene,blaOXA-51,aph(6)-Id,tet(B),...
blaOXA-51,87,81,78,...
aph(6)-Id,81,81,79,...
```

**推荐分析**:
- 关联规则挖掘
- 图论中心性指标
- 社区检测

### 5️⃣ **Network Data** (JSON格式)
```
文件: 5-network_data.json
结构: 图论格式，包含节点和边
用途: Cytoscape、交互式网络可视化
```

```json
{
  "nodes": [
    {"id": "DRR033181", "type": "sample", ...},
    {"id": "blaOXA-51", "type": "gene", ...}
  ],
  "edges": [
    {"source": "DRR033181", "target": "blaOXA-51", ...}
  ]
}
```

**推荐分析**:
- 交互式网络探索
- 关键节点识别 (hub genes)
- 网络可视化与美化

### 6️⃣ **Sample Metrics** (连续型指标)
```
文件: 6-sample_resistance_metrics.csv
结构: 行=样本，列=各种连续型耐药指标
用途: 相关性分析、回归分析、多变量分析
```

```csv
Sample,Total_ARGs,Unique_Drug_Classes,Avg_Coverage_%,Efflux_Pump_Genes,...
DRR033181,12,4,92.3,3,...
DRR033182,13,5,91.8,2,...
```

**推荐分析**:
- Pearson相关系数
- 线性回归
- 逐步回归
- 随机森林特征重要性

### 7️⃣ **Drug Class Profile** (药物类别分布)
```
文件: 7-drug_class_profile.csv
结构: 行=样本，列=药物类别，值=基因数
用途: 分层聚类、耐药谱分析
```

```csv
Sample,BETA-LACTAM,AMINOGLYCOSIDE,TETRACYCLINE,SULFONAMIDE,...
DRR033181,2,3,1,1,...
DRR033182,2,4,2,1,...
```

**推荐分析**:
- 凝聚层次聚类 (AHC)
- 样本分类
- 流行病学分析

---

## 🔬 5项深度分析详解

| # | 分析名称 | 输入数据 | 输出结果 | 关键指标 |
|---|---------|--------|--------|---------|
| 1️⃣ | **样本聚类** | 格式1 | 聚类分组 | Jaccard距离, 平均链接 |
| 2️⃣ | **基因关联** | 格式4 | 共现基因对 | 共现频率≥3 |
| 3️⃣ | **耐药分层** | 格式6 | 耐药分类 | Total_ARGs + Drug_Classes |
| 4️⃣ | **基因频率** | 格式2 | 流行度排序 | Prevalence_% |
| 5️⃣ | **药物模式** | 格式7 | 类别统计 | Mean/Max/Min计数 |

### 分析1: 样本聚类
**目的**: 识别具有相似耐药谱的样本群体

**方法**:
```
距离度量: Jaccard(仅比较有/无，忽略具体基因数)
聚类方法: Average linkage (平衡准则)
组数: 3 (可调整)
```

**应用**:
- 识别主要菌株群
- 检测可能的传播链
- 流行病学调查

### 分析2: 基因关联
**目的**: 发现经常一起出现的基因组合

**方法**:
```
共现计数: 统计基因同时出现在多少个样本中
阈值: ≥3个样本
强关联: ≥5个样本 → 可能形成"耐药平台"
```

**应用**:
- 识别协同耐药机制
- 预测新样本的耐药谱
- 指导治疗选择

### 分析3: 耐药分层
**目的**: 将样本按耐药强度分类

**分类标准**:
```
Extreme_MDR:   ≥5药物类别 AND ≥15基因 → 极端多药耐药
Severe_MDR:    ≥4药物类别 AND ≥12基因 → 严重多药耐药
Moderate_MDR:  ≥3药物类别 AND ≥10基因 → 中等多药耐药
Limited:       其他                     → 有限耐药
```

**应用**:
- 临床风险评估
- 治疗决策支持
- 预后判断

### 分析4: 基因频率
**目的**: 了解不同基因的流行度

**指标**:
```
高流行度 (≥70%):  物种特征基因，值得关注
中流行度 (30-70%): 地域/医疗机构相关
低流行度 (<30%):   罕见基因，可能是外来基因
```

**应用**:
- 指导新型诊断试剂开发
- 选择监测目标基因
- 识别新出现的耐药基因

### 分析5: 药物模式
**目的**: 了解各药物类别的耐药流行情况

**指标**:
```
Prevalence_%: 多少%的样本对该类药物耐药
Mean_Count:   平均每个样本有多少个该类基因
Max_Count:    最多的样本有多少个该类基因
```

**应用**:
- 临床用药指导
- 药物政策制定
- 感染控制策略

---

## 🎯 快速决策树

```
我想要... → 使用哪个格式/分析？

了解总体情况
    ↓
    → 查看 3-phenotype_summary.csv

识别高耐药样本
    ↓
    → 查看 3-phenotype_summary.csv，按Total_ARGs排序
    → 或使用 analysis_3_resistance_stratification.csv

找出最常见基因
    ↓
    → 查看 analysis_4_gene_frequency_profile.csv

了解基因共现模式
    ↓
    → 查看 analysis_2_gene_associations.csv

样本分类
    ↓
    → 使用 analysis_3_resistance_stratification.csv

做热力图可视化
    ↓
    → 使用 1-presence_absence_matrix.csv
    → 运行 visualization_examples.R

做网络可视化
    ↓
    → 在Cytoscape中导入 5-network_data.json

进行相关性分析
    ↓
    → 使用 6-sample_resistance_metrics.csv
    → 计算Pearson/Spearman相关

做聚类分析
    ↓
    → 使用 analysis_1_clustering_result.csv

构建预测模型
    ↓
    → 使用 1-presence_absence_matrix.csv
    → 用scikit-learn/caret做机器学习
```

---

## 📚 推荐学习资源

### 基础
- [R for Data Science](https://r4ds.had.co.nz/) - 数据分析基础
- [ggplot2 官方文档](https://ggplot2.tidyverse.org/) - 可视化
- [Python pandas 官方文档](https://pandas.pydata.org/) - 数据处理

### 进阶
- [AMRFinder 官方文档](https://www.ncbi.nlm.nih.gov/pathogens/antimicrobial-resistance/AMRFinder/)
- [Cytoscape 教程](https://cytoscape.org/documentation/)
- [Network Analysis in R](https://igraph.org/r/) - 网络分析

### 生物信息学
- [Bioconductor](https://www.bioconductor.org/) - R生物信息学包
- [Biostars](https://www.biostars.org/) - 问答社区

---

## 🛠️ 常见问题排查

| 问题 | 原因 | 解决方案 |
|-----|-----|---------|
| Python缺少pandas | 环境配置问题 | `pip install pandas numpy scipy` |
| 输出为空 | 输入数据格式不匹配 | 检查CSV列名是否正确 |
| 聚类结果不理想 | 参数不适合 | 调整聚类数或距离度量 |
| R包安装失败 | 依赖问题 | 尝试从源码安装或指定镜像 |
| 内存不足 | 数据量过大 | 进行子集分析或使用大内存服务器 |

---

## 📞 联系和反馈

- 📧 报告问题或建议改进
- 🔄 欢迎提交pull requests
- 📖 查看代码注释获取更多技术细节

---

## 📋 版本历史

| 版本 | 发布日期 | 主要更新 |
|-----|---------|---------|
| 1.0 | 2025-11-10 | 首次发布，包含7种格式和5项分析 |

---

## 📄 许可证

本系统用于科研目的，遵循开源许可证。

---

## 🙏 致谢

感谢所有使用者的反馈和建议！

---

**最后更新**: 2025-11-10  
**维护者**: 数据分析团队  
**文档版本**: 1.0
