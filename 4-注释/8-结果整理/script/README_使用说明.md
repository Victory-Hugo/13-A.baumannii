# A. baumannii 数据格式转换工具集

## 概述

本工具集包含三个主要的Python脚本，用于将A. baumannii的注释结果转换为多种格式，便于后续分析：

1. **3-Virulence_format_conversion.py** - 毒力因子数据转换
2. **4-Biocide_format_conversion.py** - 生物杀灭抵抗数据转换  
3. **5-Batch_processing.py** - 批量处理脚本

## 系统要求

### Python环境
- Python 3.6+
- 推荐使用Python 3.8或更高版本

### 依赖包
```bash
pip install pandas numpy
```

## 输入数据格式

### 毒力因子数据 (毒力因子_合并.csv)
```csv
filename,qseqid,sseqid
GCA_040009085.1,KCNOIKEC_00064,VFG050634(gb|WP_000389077.1)
```

### 生物杀灭抵抗数据 (生物杀灭抵抗_合并.csv)
```csv
filename,qseqid,sseqid  
GCA_040009085.1,KCNOIKEC_00013,lcl|NZ_LT594095.1_cds_WP_000377263.1_1849
```

## 使用方法

### 方法一：单独运行脚本

```bash
# 处理毒力因子数据
python3 3-Virulence_format_conversion.py 毒力因子_合并.csv ./virulence_output

# 处理生物杀灭抵抗数据  
python3 4-Biocide_format_conversion.py 生物杀灭抵抗_合并.csv ./biocide_output
```

### 方法二：批量处理

```bash
python3 5-Batch_processing.py
```

## 输出格式说明

每个脚本都会生成7种格式的输出文件：

### 1. presence_absence_matrix.csv
- **用途**: 机器学习、聚类分析、热力图
- **格式**: 样本 × 基因（0/1二进制矩阵）
- **适用工具**: R ggplot2, Python seaborn, heatmap

### 2. tidy_long_format.csv  
- **用途**: ggplot2分析，统计检验
- **格式**: 每行一个样本-基因关系（长格式）
- **适用工具**: R ggplot2, dplyr, Python plotly

### 3. 功能统计表
- **毒力因子**: virulence_summary.csv
- **生物杀灭抵抗**: biocide_resistance_summary.csv
- **用途**: 快速了解每个样本的功能谱
- **格式**: 样本 × 功能分类统计

### 4. gene_cooccurrence_matrix.csv
- **用途**: 基因关联分析、网络分析
- **格式**: 基因 × 基因（共现频率矩阵）
- **适用工具**: R igraph, Cytoscape, Gephi

### 5. network_data.json
- **用途**: 交互式网络可视化
- **格式**: JSON图论格式（节点+边）
- **适用工具**: Cytoscape.js, D3.js, Gephi

### 6. sample_metrics.csv
- **用途**: 相关性分析、回归分析
- **格式**: 样本 × 连续型指标
- **适用工具**: R相关性分析, Python机器学习

### 7. 功能谱文件
- **毒力因子**: virulence_function_profile.csv  
- **生物杀灭抵抗**: biocide_mechanism_profile.csv
- **用途**: 样本分层、聚类分析
- **格式**: 样本 × 功能类别计数

## 功能分类体系

### 毒力因子分类
- **Adhesion**: 黏附相关基因
- **Toxin**: 毒素相关基因
- **Iron_acquisition**: 铁获取相关基因
- **Immune_evasion**: 免疫逃逸相关基因
- **Secretion_system**: 分泌系统相关基因
- **Other_virulence**: 其他毒力相关基因
- **Unknown**: 未知功能基因

### 生物杀灭抵抗机制分类
- **Efflux_pump**: 外排泵相关基因
- **QAC_resistance**: 季铵盐类化合物抵抗
- **Heavy_metal_resistance**: 重金属抵抗（汞等）
- **Tellurite_resistance**: 亚碲酸盐抵抗
- **Arsenic_resistance**: 砷抵抗
- **Copper_resistance**: 铜抵抗
- **Silver_resistance**: 银抵抗
- **Zinc_cadmium_resistance**: 锌镉抵抗
- **Stress_response**: 压力应答
- **Biofilm_formation**: 生物膜形成
- **Other_resistance**: 其他抵抗机制

## 推荐分析流程

### Step 1: 数据概览
- 使用功能统计表进行初步描述性分析
- 了解样本间的基因数量分布

### Step 2: 聚类分析
- 使用presence_absence_matrix.csv进行层次聚类
- 识别样本间的相似性模式

### Step 3: 基因关联分析
- 使用gene_cooccurrence_matrix.csv分析基因共现模式
- 识别功能相关的基因模块

### Step 4: 网络可视化
- 使用network_data.json在Cytoscape中创建网络图
- 可视化样本-基因关系网络

### Step 5: 定量分析
- 使用sample_metrics.csv进行相关性分析
- 探索不同功能间的关联性

## 性能考虑

### 大文件处理
- 毒力因子数据: ~1100万行
- 生物杀灭抵抗数据: ~2300万行
- 建议在有足够内存的服务器上运行（推荐16GB+）

### 处理时间估计
- 毒力因子处理: 约10-30分钟
- 生物杀灭抵抗处理: 约20-60分钟
- 具体时间取决于硬件配置

## 故障排除

### 常见问题

1. **内存不足**
   ```
   解决方案: 
   - 使用更大内存的机器
   - 考虑分批处理大文件
   ```

2. **CSV解析错误**
   ```
   脚本已包含健壮的解析机制，会自动处理格式问题
   ```

3. **依赖包缺失**
   ```bash
   pip install pandas numpy
   ```

### 输出验证
每个脚本都会在控制台显示：
- 加载的数据行数
- 处理进度
- 输出文件统计信息
- 简要结果预览

## 文件结构
```
script/
├── 3-Virulence_format_conversion.py      # 毒力因子处理脚本
├── 4-Biocide_format_conversion.py        # 生物杀灭抵抗处理脚本
├── 5-Batch_processing.py                 # 批量处理脚本
└── README_使用说明.md                     # 本说明文档
```

## 更新日志

### v1.0 (当前版本)
- 支持毒力因子数据转换
- 支持生物杀灭抵抗数据转换
- 7种输出格式
- 批量处理功能
- 健壮的错误处理

## 联系信息

如有问题或建议，请联系开发者。