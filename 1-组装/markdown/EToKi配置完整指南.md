# EToKi 完整配置指南

## 概述
本文档详细记录了EToKi在conda虚拟环境中的完整配置过程，包括常见问题的解决方案，以避免日后安装出现错误。

## 配置日期
- 配置完成日期：2025年8月28日
- 系统环境：Linux (Ubuntu/WSL)
- 用户：luolintao
- 环境名称：etoki

## 主要问题和解决方案

### 1. Pilon.jar 文件缺失问题

#### 问题描述
```
ERROR - pilon ("/home/luolintao/miniconda3/envs/etoki/share/pilon-1.24-0/pilon.jar") is not present.
```

#### 问题原因
- pilon.jar文件的符号链接损坏
- Java环境配置问题

#### 解决步骤

1. **检查文件状态**
```bash
ls -la /home/luolintao/miniconda3/envs/etoki/share/pilon-1.24-0/
```

2. **修复符号链接（如果需要）**
```bash
cd /home/luolintao/miniconda3/envs/etoki/share/pilon-1.24-0/
ln -sf pilon-1.24.jar pilon.jar
```

3. **重新安装Java（如果必要）**
```bash
conda activate etoki
conda install openjdk=11 -y
```

4. **验证pilon功能**
```bash
java -jar /home/luolintao/miniconda3/envs/etoki/share/pilon-1.24-0/pilon.jar --version
```

### 2. Kraken数据库缺失问题

#### 问题描述
```
WARNING - kraken_database is not present. 
You can still use EToKi except the parameter "--kraken" in EToKi assemble will not work.
```

#### 解决方案

**方法一：使用EToKi自动下载（推荐用于网络环境良好的情况）**
```bash
conda activate etoki
EToKi.py configure --download_krakenDB
```

**方法二：手动下载并配置（本次使用的方法）**

1. **下载minikraken2数据库**
   - 文件名：`minikraken2_v2_8GB_201904.tgz`
   - 大小：约5.6GB
   - 下载地址：https://ccb.jhu.edu/software/kraken2/index.shtml#downloads

2. **复制文件到目标位置**
```bash
cd /home/luolintao/miniconda3/envs/etoki/share/etoki-1.2.3/externals/minikraken2
cp /mnt/c/Users/Administrator/Desktop/minikraken2_v2_8GB_201904.tgz .
```

3. **解压数据库**
```bash
tar -xzf minikraken2_v2_8GB_201904.tgz
```

4. **链接数据库到EToKi**
```bash
EToKi.py configure --link_krakenDB /home/luolintao/miniconda3/envs/etoki/share/etoki-1.2.3/externals/minikraken2/minikraken2_v2_8GB_201904_UPDATE
```

## 完整的环境配置验证

### 最终配置检查
运行以下命令验证所有组件：
```bash
conda activate etoki
EToKi.py configure
```

### 预期输出（成功状态）
```
bbduk ("/home/luolintao/miniconda3/envs/etoki/bin/bbduk.sh") is present.
bbmerge ("/home/luolintao/miniconda3/envs/etoki/bin/bbmerge.sh") is present.
blastn ("/home/luolintao/miniconda3/envs/etoki/bin/blastn") is present.
blastp ("/home/luolintao/miniconda3/envs/etoki/bin/blastp") is present.
bowtie2 ("/home/luolintao/miniconda3/envs/etoki/bin/bowtie2") is present.
bowtie2build ("/home/luolintao/miniconda3/envs/etoki/bin/bowtie2-build") is present.
bwa ("/home/luolintao/miniconda3/envs/etoki/bin/bwa") is present.
diamond ("/home/luolintao/miniconda3/envs/etoki/bin/diamond") is present.
fasttree ("/home/luolintao/miniconda3/envs/etoki/bin/FastTreeMP") is present.
flye ("/home/luolintao/miniconda3/envs/etoki/bin/flye") is present.
kraken2 ("/home/luolintao/miniconda3/envs/etoki/bin/kraken2") is present.
lastal ("/home/luolintao/miniconda3/envs/etoki/bin/lastal") is present.
lastdb ("/home/luolintao/miniconda3/envs/etoki/bin/lastdb") is present.
makeblastdb ("/home/luolintao/miniconda3/envs/etoki/bin/makeblastdb") is present.
megahit ("/home/luolintao/miniconda3/envs/etoki/bin/megahit") is present.
minimap2 ("/home/luolintao/miniconda3/envs/etoki/bin/minimap2") is present.
mmseqs ("/home/luolintao/miniconda3/envs/etoki/bin/mmseqs") is present.
nextpolish ("/home/luolintao/miniconda3/envs/etoki/bin/nextPolish") is present.
pilercr ("/home/luolintao/miniconda3/envs/etoki/bin/pilercr") is present.
pilon ("/home/luolintao/miniconda3/envs/etoki/share/pilon-1.24-0/pilon.jar") is present.
rapidnj ("/home/luolintao/miniconda3/envs/etoki/bin/rapidnj") is present.
raxml ("/home/luolintao/miniconda3/envs/etoki/bin/raxmlHPC") is present.
raxml_ng ("/home/luolintao/miniconda3/envs/etoki/bin/raxml-ng") is present.
repair ("/home/luolintao/miniconda3/envs/etoki/bin/repair.sh") is present.
samtools ("/home/luolintao/miniconda3/envs/etoki/bin/samtools") is present.
spades ("/home/luolintao/miniconda3/envs/etoki/bin/spades.py") is present.
trf ("/home/luolintao/miniconda3/envs/etoki/bin/trf") is present.
usearch ("/home/luolintao/miniconda3/envs/etoki/bin/blastp") is present.
Configuration complete.
```

## 重要目录和文件路径

### EToKi相关路径
- 主程序：`/home/luolintao/miniconda3/envs/etoki/bin/EToKi.py`
- 配置目录：`/home/luolintao/miniconda3/envs/etoki/share/etoki-1.2.3/`
- Pilon路径：`/home/luolintao/miniconda3/envs/etoki/share/pilon-1.24-0/pilon.jar`
- Kraken数据库：`/home/luolintao/miniconda3/envs/etoki/share/etoki-1.2.3/externals/minikraken2/`

### 数据库文件结构
```
minikraken2_v2_8GB_201904_UPDATE/
├── database100mers.kmer_distrib
├── database150mers.kmer_distrib
├── database200mers.kmer_distrib
├── hash.k2d
├── opts.k2d
└── taxo.k2d
```

## 故障排除指南

### 1. Java相关问题
如果出现Java错误，检查Java版本：
```bash
conda activate etoki
java -version
```

如果Java版本不兼容，重新安装：
```bash
conda install openjdk=11 -y
```
下载地址：https://benlangmead.github.io/aws-indexes/k2
### 2. Kraken数据库问题
如果kraken数据库链接失败：
```bash
# 检查数据库文件完整性
ls -la /home/luolintao/miniconda3/envs/etoki/share/etoki-1.2.3/externals/minikraken2/minikraken2_v2_8GB_201904_UPDATE/

# 重新链接数据库
EToKi.py configure --link_krakenDB /home/luolintao/miniconda3/envs/etoki/share/etoki-1.2.3/externals/minikraken2/minikraken2_v2_8GB_201904_UPDATE
```

### 3. 权限问题
如果遇到权限问题：
```bash
# 修复目录权限
chmod -R 755 /home/luolintao/miniconda3/envs/etoki/share/etoki-1.2.3/
```

## 使用建议

### 1. 环境激活
每次使用EToKi前，确保激活正确的环境：
```bash
conda activate etoki
```

### 2. 定期检查配置
建议定期运行配置检查：
```bash
EToKi.py configure
```

### 3. 备份重要文件
建议备份以下重要配置：
- 整个etoki环境：`conda env export -n etoki > etoki_environment.yml`
- kraken数据库文件（如果存储空间允许）

## 常用EToKi命令示例

### 基本组装命令
```bash
# 使用kraken进行质量控制的组装
EToKi.py assemble --pe1 read1.fastq --pe2 read2.fastq --kraken -o output_dir

# 不使用kraken的组装
EToKi.py assemble --pe1 read1.fastq --pe2 read2.fastq -o output_dir
```

### 系统核心进化分析
```bash
EToKi.py MLSType -i genome.fasta -o mlst_output
```

## 版本信息
- EToKi版本：1.2.3
- Kraken2版本：2.14-0
- Pilon版本：1.24
- Java版本：OpenJDK 11
- 数据库版本：minikraken2_v2_8GB_201904_UPDATE

## 总结
通过以上配置，EToKi环境已完全配置完成，所有依赖项都已正确安装和配置。现在可以正常使用EToKi进行基因组组装和分析工作，包括使用kraken进行质量控制。

如果在日后使用中遇到问题，请参考本文档的故障排除部分，或重新执行相应的配置步骤。
