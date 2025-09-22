# Spacedust 分析脚本说明

本目录包含重构自Jupyter notebook的Spacedust分析脚本，采用Shell + Python的模块化设计。

## 文件结构

```
script/
├── run_spacedust.sh           # 主分析脚本（Shell）
├── spacedust_postprocess.py   # 后处理脚本（Python）
├── setup_tools.sh             # 工具设置检查脚本
├── run_example.sh             # 示例运行脚本
├── config.sh                  # 配置文件
├── software_paths.conf        # 软件路径配置（自动生成）
└── README.md                  # 本说明文档
```

## 快速开始

### 1. 环境检查

首先运行工具设置脚本，检查所有依赖软件和数据库：

```bash
bash setup_tools.sh
```

这个脚本会检查：
- Spacedust软件是否可用
- Prodigal软件是否可用（用于基因预测）
- Foldseek软件是否可用（可选，用于结构搜索）
- KEGG数据库是否存在
- Python环境和必需包
- 示例数据

### 2. 运行示例分析

使用Example目录中的示例数据进行测试：

```bash
bash run_example.sh
```

这个脚本会：
- 自动检测示例数据类型（FNA或FAA）
- 根据文件数量选择合适的分析模式
- 运行完整的Spacedust分析流程
- 生成结果文件和统计信息

### 3. 自定义分析

使用主脚本进行自定义分析：

```bash
# 基本用法：使用KEGG数据库分析基因组
bash run_spacedust.sh -i /path/to/genomes -j my_analysis

# 显示完整帮助信息
bash run_spacedust.sh -h
```

## 详细使用说明

### 主分析脚本 (run_spacedust.sh)

主要功能：
- 文件输入验证和处理
- Prodigal基因预测（可选）
- Spacedust聚类搜索
- 调用Python后处理脚本
- 结果文件整理

#### 必需参数

- `-i, --input DIR`: 输入基因组文件目录

#### 可选参数

- `-j, --jobname NAME`: 任务名称（默认：test）
- `-m, --mode MODE`: 输入模式
  - `query-target`: 查询基因组与目标数据库比较
  - `all-against-all`: 查询基因组间两两比较
- `-d, --database DB`: 目标数据库类型
  - `KEGG_70`: 使用预建的KEGG数据库
  - `self-uploaded`: 使用自定义目标基因组
- `-t, --target DIR`: 目标基因组目录（当database为self-uploaded时使用）
- `-s, --search MODE`: 搜索模式
  - `MMseqs2`: 序列同源性搜索（默认）
  - `Foldseek`: 结构相似性搜索
- `-p, --prodigal BOOL`: 是否运行Prodigal（默认：true）
- `-g, --max-gap NUM`: 最大基因间隔（默认：3）
- `-o, --output DIR`: 输出目录
- `-w, --workdir DIR`: 工作目录

#### 使用示例

```bash
# 示例1：基本分析（FNA文件，需要基因预测）
bash run_spacedust.sh \
  -i /path/to/fna_genomes \
  -j basic_analysis \
  -m query-target \
  -d KEGG_70

# 示例2：all-against-all分析
bash run_spacedust.sh \
  -i /path/to/genomes \
  -j all_vs_all \
  -m all-against-all

# 示例3：使用自定义目标数据库
bash run_spacedust.sh \
  -i /path/to/query_genomes \
  -t /path/to/target_genomes \
  -j custom_db_analysis \
  -m query-target \
  -d self-uploaded

# 示例4：FAA文件分析（跳过基因预测）
bash run_spacedust.sh \
  -i /path/to/faa_genomes \
  -j protein_analysis \
  -p false
```

### 后处理脚本 (spacedust_postprocess.py)

功能：
- 处理Spacedust原始输出
- 整合查询和目标序列信息
- 生成可视化数据文件
- 计算统计信息

通常由主脚本自动调用，也可以单独运行：

```bash
python3 spacedust_postprocess.py \
  --jobname test \
  --input-mode query-target \
  --target-db KEGG_70 \
  --workdir /path/to/workdir
```

## 输入文件格式

### 基因组序列文件

1. **FNA格式**（需要基因预测）
   - 核酸序列文件
   - 需要设置`--prodigal true`
   - 脚本会自动运行Prodigal生成FAA文件

2. **FAA格式**（已预测的蛋白质序列）
   - 蛋白质序列文件
   - 需要设置`--prodigal false`
   - 序列头需要符合Prodigal格式或类似格式

### 文件命名要求

- 文件扩展名：`.fna`或`.faa`
- 避免使用特殊字符和空格
- 建议使用有意义的文件名（如基因组ID）

## 输出文件说明

### 主要结果文件

1. **{jobname}**: 主要结果文件（Spacedust原始输出）
2. **{jobname}_plot**: 可视化数据文件（后处理后的结果）
3. **{jobname}_statistics.txt**: 统计信息汇总
4. **database/{jobname}_input_pref**: 输入序列前缀信息

### 文件内容说明

- **主要结果文件**: 包含所有聚类匹配信息，格式为制表符分隔
- **可视化数据文件**: 整理后的数据，包含基因组位置、序列名称等信息
- **统计信息**: 分析结果的数量统计和摘要信息

## 故障排除

### 常见问题

1. **"Spacedust可执行文件不存在"**
   - 检查`download/spacedust`目录是否存在
   - 确保可执行文件有执行权限：`chmod +x download/spacedust/bin/spacedust`

2. **"KEGG数据库不存在"**
   - 检查`database/keggclusterdb`目录是否存在
   - 确保KEGG数据库已正确解压

3. **"未找到.fna/.faa文件"**
   - 检查输入目录路径是否正确
   - 确保文件扩展名正确（`.fna`或`.faa`）

4. **"pandas模块未找到"**
   - 安装pandas：`pip3 install pandas`
   - 或使用conda：`conda install pandas`

5. **"Prodigal基因预测失败"**
   - 检查Prodigal是否可执行：`download/prodigal -h`
   - 检查输入FNA文件格式是否正确

### 调试方法

1. **运行工具检查脚本**：
   ```bash
   bash setup_tools.sh
   ```

2. **查看详细错误信息**：
   - 主脚本会显示彩色的错误信息
   - Python脚本使用`--verbose`参数获取详细日志

3. **检查临时文件**：
   - 工作目录中的`tmp/`目录包含中间文件
   - 可以检查Spacedust的原始输出

## 性能建议

### 硬件要求

- **内存**: 建议8GB以上（取决于基因组数量和大小）
- **存储**: 确保有足够的磁盘空间存储临时文件
- **CPU**: 多核CPU可以加速分析过程

### 参数优化

- **max-gene-gap**: 根据分析目标调整最大基因间隔
- **search-mode**: MMseqs2较快，Foldseek更敏感但耗时更长

### 大规模数据处理

- 对于大量基因组，考虑分批处理
- 使用高性能计算集群时，可以并行运行多个任务

## 引用信息

如果使用本脚本进行研究，请引用Spacedust原始论文和相关软件：

- **Spacedust**: [官方GitHub](https://github.com/soedinglab/spacedust)
- **MMseqs2**: Steinegger & Söding (2017)
- **Prodigal**: Hyatt et al. (2010)

## 更新日志

- v1.0: 初始版本，基于Jupyter notebook重构
- 功能完整，支持所有原notebook功能
- 添加错误处理和用户友好的输出

## 联系信息

如有问题或建议，请联系脚本维护者或访问Spacedust官方项目页面。