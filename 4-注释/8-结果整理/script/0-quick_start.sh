#!/bin/bash
# 快速开始：AMRFinder 结果数据转换和分析
# 使用这个脚本来执行完整的数据处理流程

set -e

# ============ 配置区 ============
INPUT_CSV="${1:-/mnt/d/1-ABaumannii/1-注释汇总/2-NCBI-Sequence/All_Samples_抗生素耐药.csv}"
OUTPUT_DIR="${2:-./amr_analysis_output}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ============ 色彩定义 ============
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ============ 函数定义 ============
log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

log_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

log_warn() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

log_error() {
    echo -e "${RED}✗ $1${NC}"
}

# ============ 主流程 ============
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}🧬 AMRFinder 结果数据转换和分析${NC}"
echo -e "${BLUE}========================================${NC}\n"

# 检查输入文件
if [[ ! -f "$INPUT_CSV" ]]; then
    log_error "输入文件不存在: $INPUT_CSV"
    exit 1
fi
log_success "找到输入文件: $INPUT_CSV"

# 创建输出目录
mkdir -p "$OUTPUT_DIR"
log_success "输出目录: $OUTPUT_DIR"

# Step 1: 数据格式转换
echo -e "\n${YELLOW}━━━ Step 1: 数据格式转换 ━━━${NC}"
log_info "将AMRFinder结果转换为7种分析格式..."
python3 "$SCRIPT_DIR/2-AMR_format_conversion.py" "$INPUT_CSV" "$OUTPUT_DIR"

if [[ $? -eq 0 ]]; then
    log_success "格式转换完成"
else
    log_error "格式转换失败"
    exit 1
fi

# Step 2: 数据分析
echo -e "\n${YELLOW}━━━ Step 2: 数据分析 ━━━${NC}"
log_info "执行5项深度分析..."
python3 "$SCRIPT_DIR/3-format_analysis_examples.py" "$OUTPUT_DIR"

if [[ $? -eq 0 ]]; then
    log_success "数据分析完成"
else
    log_error "数据分析失败"
    exit 1
fi

# Step 3: 生成统计摘要
echo -e "\n${YELLOW}━━━ Step 3: 生成统计摘要 ━━━${NC}"
cat > "$OUTPUT_DIR/SUMMARY.txt" << 'EOF'
# ================================
# AMRFinder 数据分析总结
# ================================

## 📁 生成的文件及其用途

### 第一级：数据格式文件
这些文件是转换的原始格式，为后续分析提供基础。

1. **1-presence_absence_matrix.csv** [矩阵格式]
   - 内容：样本（行）× 基因（列）的0/1矩阵
   - 用途：机器学习、聚类分析、热力图可视化
   - 推荐工具：R ggplot2, Python seaborn, scikit-learn
   - 典型分析：
     * 层次聚类 (hierarchical clustering)
     * PCA主成分分析
     * t-SNE降维可视化

2. **2-tidy_long_format.csv** [长表格式]
   - 内容：每行代表一个样本-基因关系
   - 用途：统计分析、可视化、多变量分析
   - 推荐工具：R ggplot2/tidyverse, Python plotly
   - 典型分析：
     * 分组比较 (grouped comparison)
     * 方差分析 ANOVA
     * 非参数检验

3. **3-phenotype_summary.csv** [样本快览]
   - 内容：每个样本的耐药谱摘要
   - 用途：快速查阅、初步描述性统计
   - 推荐工具：Excel, 任何统计软件
   - 典型分析：
     * 样本过滤
     * 基本统计量计算
     * 异常值识别

4. **4-gene_cooccurrence_matrix.csv** [基因关系矩阵]
   - 内容：基因（行和列）的共现频率
   - 用途：基因关联分析、网络分析
   - 推荐工具：R igraph, Cytoscape, Gephi, networkx
   - 典型分析：
     * 图论聚类
     * 社区检测 (community detection)
     * 中心性指标计算 (centrality measures)

5. **5-network_data.json** [图论格式]
   - 内容：样本-基因网络的节点和边
   - 用途：交互式网络可视化、大规模关系展示
   - 推荐工具：Cytoscape, D3.js, Gephi导入, BioRender
   - 典型分析：
     * 交互式网络浏览
     * 关键节点识别
     * 网络拓扑分析

6. **6-sample_resistance_metrics.csv** [连续型指标]
   - 内容：样本级别的多个连续型指标
   - 用途：相关性分析、回归分析、多变量分析
   - 推荐工具：R ggplot2, Python scipy/sklearn
   - 典型分析：
     * Pearson/Spearman相关性
     * 线性回归
     * 随机森林等机器学习

7. **7-drug_class_profile.csv** [药物类别矩阵]
   - 内容：样本（行）× 药物类别（列）的计数矩阵
   - 用途：分层、聚类、热力图
   - 推荐工具：heatmap, 聚类算法
   - 典型分析：
     * 样本分类/分层
     * 耐药谱聚类
     * 流行病学分析

### 第二级：分析结果文件
这些是已经完成的具体分析。

1. **analyses/analysis_1_clustering_result.csv**
   - 样本的聚类分组结果
   - 应用：识别具有相似耐药谱的样本群体

2. **analyses/analysis_2_gene_associations.csv**
   - 高频共现的基因对
   - 应用：识别关键的耐药基因组合

3. **analyses/analysis_3_resistance_stratification.csv**
   - 样本的耐药强度分类
   - 应用：临床风险评估和治疗决策

4. **analyses/analysis_4_gene_frequency_profile.csv**
   - 每个基因的流行度
   - 应用：识别主要循环的耐药基因

5. **analyses/analysis_5_drug_class_patterns.csv**
   - 药物类别耐药模式统计
   - 应用：了解整体耐药谱

### 第三级：可视化代码
这些是现成的代码模板，可直接使用或修改。

1. **visualization_examples.R**
   - R语言可视化示例
   - 包含：热力图、条形图、散点图等

2. **visualization_examples.py**
   - Python可视化示例
   - 包含：热力图、条形图、散点图等

## 🔬 推荐分析流程

### 初步探索 (Exploratory)
1. 查看 3-phenotype_summary.csv - 了解总体情况
2. 运行聚类分析 (analysis_1_clustering_result.csv)
3. 绘制热力图 (1-presence_absence_matrix.csv)

### 深度分析 (Mechanistic)
1. 分析基因共现 (analysis_2_gene_associations.csv)
2. 检查基因频率 (analysis_4_gene_frequency_profile.csv)
3. 进行相关性分析 (6-sample_resistance_metrics.csv)

### 应用分析 (Application)
1. 样本分层 (analysis_3_resistance_stratification.csv)
2. 网络可视化 (5-network_data.json in Cytoscape)
3. 对比临床数据或地理信息

## 📊 常见分析问题解答

### Q1: 我想找出最常见的耐药基因
A: 查看 analysis_4_gene_frequency_profile.csv，按 Prevalence_% 排序

### Q2: 我想了解哪些基因经常一起出现
A: 查看 analysis_2_gene_associations.csv，按 CoOccurrence_Count 排序

### Q3: 我想对样本进行分类
A: 使用 analysis_3_resistance_stratification.csv 的分类结果

### Q4: 我想进行统计学检验
A: 使用 2-tidy_long_format.csv 进行 ggplot2/tidyverse 分析

### Q5: 我想制作热力图
A: 使用 1-presence_absence_matrix.csv 和 visualization_examples.R/py

### Q6: 我想进行PCA/降维分析
A: 使用 1-presence_absence_matrix.csv，参考示例代码

### Q7: 我想制作网络图
A: 使用 5-network_data.json 在 Cytoscape 或 Gephi 中打开

## 💡 数据解释指南

### 耐药基因类型
- **Core**: 通常存在于该物种的基因组中
- **Plus**: 应激反应、毒性因子、金属抗性等扩展基因

### 覆盖度 (Coverage)
- ≥90%: 基因完整，可信度高
- 70-90%: 基因主要部分存在，可能在contig末端
- <70%: 基因片段化，需谨慎解释

### 同源性 (Identity)
- ≥99%: 完全匹配，高度同源
- 95-99%: 高度同源，可能是变体
- <95%: 同源性较低，可能是远源基因

### 多药耐药指数 (MDR Index)
- <0.8: 低耐药
- 0.8-1.2: 中等耐药
- >1.2: 高度多药耐药

## 🔧 技术细节

### 聚类方法
- 距离度量: Jaccard距离
- 链接方法: Average linkage
- 聚类数: 3 (可调整)

### 共现判定
- 阈值: ≥3个样本共现
- 强关联: ≥5个样本共现

### 分层标准
- 极端MDR: ≥5药物类别 AND ≥15个基因
- 严重MDR: ≥4药物类别 AND ≥12个基因
- 中等MDR: ≥3药物类别 AND ≥10个基因
- 有限耐药: 其他

## 📚 参考资源

### 软件和工具
- **Cytoscape**: http://www.cytoscape.org/
- **Gephi**: https://gephi.org/
- **R ggplot2**: https://ggplot2.tidyverse.org/
- **Python seaborn**: https://seaborn.pydata.org/

### 数据分析教程
- R for Data Science: https://r4ds.had.co.nz/
- Python Data Science: https://www.oreilly.com/

### AMRFinder官方文档
- NCBI AMRFinder: https://www.ncbi.nlm.nih.gov/pathogens/antimicrobial-resistance/AMRFinder/

## 📝 使用统计

生成时间: 2025-11-10
数据版本: All_Samples_抗生素耐药.csv
样本数量: [参考phenotype_summary.csv]
基因总数: [参考analysis_4_gene_frequency_profile.csv]
EOF

log_success "生成统计摘要"
cat "$OUTPUT_DIR/SUMMARY.txt"

# 最终总结
echo -e "\n${BLUE}========================================${NC}"
echo -e "${GREEN}✅ 所有数据处理完成！${NC}"
echo -e "${BLUE}========================================${NC}\n"

echo -e "📊 ${YELLOW}生成的文件位置：${NC}"
echo "   📁 $OUTPUT_DIR"
echo ""
echo -e "📄 ${YELLOW}主要输出文件：${NC}"
ls -lh "$OUTPUT_DIR"/*.csv 2>/dev/null | awk '{print "   " $9}'
echo ""
echo -e "🔍 ${YELLOW}分析结果：${NC}"
if [[ -d "$OUTPUT_DIR/analyses" ]]; then
    ls -lh "$OUTPUT_DIR/analyses"/*.csv 2>/dev/null | awk '{print "   " $9}'
fi
echo ""
echo -e "📖 ${YELLOW}下一步建议：${NC}"
echo "   1. 查看 $OUTPUT_DIR/SUMMARY.txt 了解数据格式"
echo "   2. 用Excel打开 phenotype_summary.csv 进行快速浏览"
echo "   3. 用R或Python运行 visualization_examples.R/py 制作图表"
echo "   4. 在Cytoscape中导入 network_data.json 进行网络分析"
echo ""
