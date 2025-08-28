#!/bin/bash

# EToKi环境完整打包脚本
# 作者：配置于2025年8月28日
# 功能：将完整配置的etoki环境打包，包括所有依赖和数据库

echo "开始打包EToKi环境..."
echo "打包时间：$(date)"

# 设置变量
CONDA_ENV_NAME="etoki"
PACKAGE_NAME="etoki_complete_$(date +%Y%m%d_%H%M%S)"
PACKAGE_DIR="/tmp/${PACKAGE_NAME}"
CONDA_PREFIX="/home/luolintao/miniconda3"

# 创建打包目录
mkdir -p "${PACKAGE_DIR}"
cd "${PACKAGE_DIR}"

echo "步骤1: 导出conda环境配置..."
# 导出环境配置文件
conda env export -n ${CONDA_ENV_NAME} > etoki_environment.yml

echo "步骤2: 打包整个conda环境目录..."
# 打包整个etoki环境目录（包含所有二进制文件和依赖）
tar -czf etoki_env_binaries.tar.gz -C "${CONDA_PREFIX}/envs" ${CONDA_ENV_NAME}

echo "步骤3: 单独打包kraken数据库..."
# 打包kraken数据库（这是最大的文件）
KRAKEN_DB_PATH="${CONDA_PREFIX}/envs/${CONDA_ENV_NAME}/share/etoki-1.2.3/externals/minikraken2"
if [ -d "${KRAKEN_DB_PATH}" ]; then
    tar -czf kraken_database.tar.gz -C "${KRAKEN_DB_PATH}" .
    echo "Kraken数据库已打包"
else
    echo "警告: 未找到Kraken数据库目录"
fi

echo "步骤4: 创建安装脚本..."
# 创建自动安装脚本
cat > install_etoki.sh << 'EOF'
#!/bin/bash

# EToKi环境自动安装脚本
# 使用方法: ./install_etoki.sh

set -e  # 遇到错误立即退出

echo "=== EToKi环境安装程序 ==="
echo "开始时间: $(date)"

# 检查conda是否已安装
if ! command -v conda &> /dev/null; then
    echo "错误: 未检测到conda，请先安装conda"
    exit 1
fi

echo "✓ 检测到conda: $(conda --version)"

# 获取当前用户的conda路径
CONDA_BASE=$(conda info --base)
echo "✓ Conda安装路径: ${CONDA_BASE}"

# 检查必要文件是否存在
if [ ! -f "etoki_environment.yml" ]; then
    echo "错误: 未找到etoki_environment.yml文件"
    exit 1
fi

if [ ! -f "etoki_env_binaries.tar.gz" ]; then
    echo "错误: 未找到etoki_env_binaries.tar.gz文件"
    exit 1
fi

echo "步骤1: 创建conda环境..."
# 从yml文件创建环境
conda env create -f etoki_environment.yml

echo "步骤2: 解压二进制文件..."
# 解压二进制文件到conda环境目录
tar -xzf etoki_env_binaries.tar.gz -C "${CONDA_BASE}/envs/"

echo "步骤3: 安装kraken数据库..."
# 检查并安装kraken数据库
if [ -f "kraken_database.tar.gz" ]; then
    KRAKEN_TARGET="${CONDA_BASE}/envs/etoki/share/etoki-1.2.3/externals/minikraken2"
    mkdir -p "${KRAKEN_TARGET}"
    tar -xzf kraken_database.tar.gz -C "${KRAKEN_TARGET}"
    echo "✓ Kraken数据库已安装"
else
    echo "警告: 未找到kraken数据库文件，需要手动配置"
fi

echo "步骤4: 验证安装..."
# 激活环境并验证
source "${CONDA_BASE}/etc/profile.d/conda.sh"
conda activate etoki

# 验证EToKi配置
echo "正在验证EToKi配置..."
if EToKi.py configure > etoki_config_check.log 2>&1; then
    echo "✓ EToKi配置验证成功"
    echo "配置检查日志已保存到: etoki_config_check.log"
else
    echo "⚠ EToKi配置验证失败，请检查日志: etoki_config_check.log"
fi

echo ""
echo "=== 安装完成 ==="
echo "完成时间: $(date)"
echo ""
echo "使用方法:"
echo "1. 激活环境: conda activate etoki"
echo "2. 检查配置: EToKi.py configure"
echo "3. 运行分析: EToKi.py assemble --help"
echo ""
echo "如遇问题，请查看配置日志: etoki_config_check.log"
EOF

chmod +x install_etoki.sh

echo "步骤5: 创建使用说明文档..."
# 创建详细的使用说明
cat > README_安装使用指南.md << 'EOF'
# EToKi环境完整安装使用指南

## 📦 包内容说明

本打包包含以下文件：
- `etoki_environment.yml` - conda环境配置文件
- `etoki_env_binaries.tar.gz` - 完整的二进制环境文件（约2-3GB）
- `kraken_database.tar.gz` - Kraken2数据库文件（约8GB）
- `install_etoki.sh` - 自动安装脚本
- `README_安装使用指南.md` - 本说明文档

## 🚀 快速安装（推荐）

### 方法一：一键自动安装

1. 将所有文件上传到目标服务器
2. 确保有足够的磁盘空间（至少15GB）
3. 运行自动安装脚本：

```bash
./install_etoki.sh
```

### 方法二：手动安装

如果自动安装遇到问题，可以按以下步骤手动安装：

#### 步骤1：检查conda环境
```bash
conda --version
conda info --base
```

#### 步骤2：创建环境
```bash
conda env create -f etoki_environment.yml
```

#### 步骤3：解压二进制文件
```bash
# 获取conda安装路径
CONDA_BASE=$(conda info --base)
tar -xzf etoki_env_binaries.tar.gz -C "${CONDA_BASE}/envs/"
```

#### 步骤4：安装数据库
```bash
# 创建数据库目录
KRAKEN_DIR="${CONDA_BASE}/envs/etoki/share/etoki-1.2.3/externals/minikraken2"
mkdir -p "${KRAKEN_DIR}"
tar -xzf kraken_database.tar.gz -C "${KRAKEN_DIR}"
```

#### 步骤5：验证安装
```bash
conda activate etoki
EToKi.py configure
```

## 🔧 使用方法

### 激活环境
```bash
conda activate etoki
```

### 检查配置
```bash
EToKi.py configure
```

### 基本组装命令
```bash
# 使用kraken质控的组装
EToKi.py assemble --pe1 read1.fastq --pe2 read2.fastq --kraken -o output_dir

# 不使用kraken的组装
EToKi.py assemble --pe1 read1.fastq --pe2 read2.fastq -o output_dir
```

### 查看帮助
```bash
EToKi.py --help
EToKi.py assemble --help
```

## 🛠 故障排除

### 常见问题1：权限错误
```bash
# 修复权限问题
chmod -R 755 $(conda info --base)/envs/etoki/
```

### 常见问题2：Java环境问题
```bash
conda activate etoki
java -version
# 如果Java有问题，重新安装
conda install openjdk=11 -y
```

### 常见问题3：Kraken数据库问题
```bash
# 检查数据库文件
ls -la $(conda info --base)/envs/etoki/share/etoki-1.2.3/externals/minikraken2/

# 重新链接数据库
EToKi.py configure --link_krakenDB $(conda info --base)/envs/etoki/share/etoki-1.2.3/externals/minikraken2/minikraken2_v2_8GB_201904_UPDATE
```

### 常见问题4：磁盘空间不足
安装需要约15GB磁盘空间：
- conda环境: ~3GB
- kraken数据库: ~8GB  
- 临时文件: ~4GB

## 📋 系统要求

### 最低要求
- 操作系统：Linux (Ubuntu 18.04+, CentOS 7+)
- 内存：8GB RAM
- 磁盘空间：15GB可用空间
- 已安装conda (Anaconda/Miniconda)

### 推荐配置
- 内存：16GB+ RAM
- 磁盘空间：50GB+ 可用空间
- CPU：8核以上

## 🔍 验证安装成功

安装成功后，运行以下命令应该看到所有组件都显示"is present"：

```bash
conda activate etoki
EToKi.py configure
```

预期输出应包含：
```
pilon (...) is present.
kraken2 (...) is present.
Configuration complete.
```

## 📞 技术支持

如果遇到问题：
1. 首先查看安装日志：`etoki_config_check.log`
2. 检查磁盘空间和权限
3. 确保conda版本兼容（推荐conda 4.8+）
4. 参考故障排除部分

## 📄 版本信息
- 打包日期：2025年8月28日
- EToKi版本：1.2.3
- Kraken数据库：minikraken2_v2_8GB_201904_UPDATE
- Python版本：3.x
- 测试环境：Ubuntu/WSL

EOF

echo "步骤6: 生成打包信息..."
# 创建打包信息文件
cat > package_info.txt << EOF
EToKi环境打包信息
================

打包时间: $(date)
打包主机: $(hostname)
用户: $(whoami)
conda版本: $(conda --version)
系统信息: $(uname -a)

环境信息:
- 环境名称: ${CONDA_ENV_NAME}
- 环境路径: ${CONDA_PREFIX}/envs/${CONDA_ENV_NAME}

包含文件:
- etoki_environment.yml (环境配置)
- etoki_env_binaries.tar.gz (二进制文件)
- kraken_database.tar.gz (数据库文件)
- install_etoki.sh (安装脚本)
- README_安装使用指南.md (使用说明)

文件大小:
$(ls -lh)

总大小: $(du -sh . | cut -f1)
EOF

echo ""
echo "=== 打包完成 ==="
echo "打包目录: ${PACKAGE_DIR}"
echo "文件列表:"
ls -lh "${PACKAGE_DIR}"
echo ""
echo "总大小: $(du -sh ${PACKAGE_DIR} | cut -f1)"
echo ""
echo "建议压缩整个目录:"
echo "cd /tmp && tar -czf ${PACKAGE_NAME}.tar.gz ${PACKAGE_NAME}/"
echo ""
echo "或者创建可执行的安装包:"
echo "cd /tmp && tar -czf ${PACKAGE_NAME}_portable.tar.gz ${PACKAGE_NAME}/"

# 创建最终的压缩包
cd /tmp
echo "正在创建最终压缩包..."
tar -czf "${PACKAGE_NAME}.tar.gz" "${PACKAGE_NAME}/"

echo ""
echo "🎉 打包完全完成!"
echo "最终文件: /tmp/${PACKAGE_NAME}.tar.gz"
echo "文件大小: $(ls -lh /tmp/${PACKAGE_NAME}.tar.gz | awk '{print $5}')"
echo ""
echo "传输到其他服务器后，解压并运行 install_etoki.sh 即可安装"
