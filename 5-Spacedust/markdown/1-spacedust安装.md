# 安装
**Spacedust** 是一个模块化工具包，用于在多个基因组之间识别保守基因簇，基于同源性和基因邻域的保守性。
Spacedust 结合了 **Foldseek** 的快速灵敏结构比对和 **MMseqs2** 的同源性搜索能力。
它引入了一种新的方法：在基因组对之间聚合同源性比对结果，并通过凝聚层次聚类算法识别具有保守基因邻域的簇。
Spacedust 是在 **C++** 中实现的开源软件（GPLv3 许可），可用于 Linux 和 macOS，支持多核高效运行。

```SH
# 静态 Linux AVX2 构建（检查：cat /proc/cpuinfo | grep avx2）
wget https://mmseqs.com/spacedust/spacedust-linux-avx2.tar.gz; tar xvzf spacedust-linux-avx2.tar.gz; export PATH=$(pwd)/spacedust/bin/:$PATH

# 静态 Linux SSE4.1 构建（检查：cat /proc/cpuinfo | grep sse4_1）
wget https://mmseqs.com/spacedust/spacedust-linux-sse41.tar.gz; tar xvzf spacedust-linux-sse41.tar.gz; export PATH=$(pwd)/spacedust/bin/:$PATH

# 静态 macOS 构建（通用二进制，支持 SSE4.1/AVX2/M1 NEON）
wget https://mmseqs.com/spacedust/spacedust-osx-universal.tar.gz; tar xvzf spacedust-osx-universal.tar.gz; export PATH=$(pwd)/spacedust/bin/:$PATH

# Conda 安装（Linux 和 macOS）
conda install -c conda-forge -c bioconda spacedust
```

**推荐使用conda安装**，因为它会自动处理依赖关系并确保与系统的兼容性。
