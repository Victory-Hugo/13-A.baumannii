# 参考教程
> https://zhuanlan.zhihu.com/p/543631632

# 1、AMRFinderPlus 概述
AMRFinderPlus (NCBI Antimicrobial Resistance Gene Finder Plus) 利用附带的数据库可识别细菌蛋白序列和基因组Assembly序列中的获得性抗菌素耐药性基因，以及已知的几个物种的耐药性相关点突变。

默认情况下，AMRFinderPlus 返回的结果将与原始 AMRFinder 返回的结果相似，并包括已知功能的抗菌素耐药基因。使用--plus 选项包括包含其他基因类别的结果，例如毒力因子、杀菌剂、热、酸和金属抗性基因。

# 2、安装
AMRFinderPlus 需要 HMMER、BLAST+、Linux 和 perl。**这里推荐使用BioConda 的安装源安装该软件**。

使用 conda 安装 AMRFinderPlus ：

首先需要激活conda 环境
`source ~/miniconda3/bin/activate`
或者
`source ~/anaconda3/bin/activate`

为AMRFinderPlus 创建一个单独的conda环境（推荐），并自动安装  ncbi-amrfinderplus
`conda create -n AMRFinderPlus  -y -c bioconda -c conda-forge ncbi-amrfinderplus `
create -n AMRFinderPlus 创建一个名为AMRFinderPlus的虚拟环境
-y 无人值守 自动开始安装 不添加该选项则需要在安装时，等待键入同意安装的指令 
-c bioconda -c conda-forge  添加安装的源 bioconda 和conda-forge
等待安装完成

# 3、测试安装
激活刚刚创建的环境AMRFinderPlus
`source ~/miniconda3/bin/activate AMRFinderPlus`
`amrfinder -h`
如无报错应该出现各参数的帮助信息
# 4、简单使用
amrfinder是针对基因组尺度大小的数据分析耐药基因的，可能需要使用到基因组的gff注释文件，一般ncbi的公开基因组数据可以直接下载蛋白质序列文件（\*.faa）、CDS的DNA序列文件（\*.fna）以及对应的基因组的gff注释文件。如果自己的未发布数据可以使用prokka获得上述文件。但是由于amrfinder格式要求，prokka得到的gff注释文件不能直接用于amrfinder耐药基因注释，因此对prokka得到的gff注释文件需要指定注释文件格式：

`--annotation_format prokka `
对于pgap（NCBI Prokaryotic Genome Annotation Pipeline）本地版注释的gff和faa文件需要蛋白ID和gff中Name字段相同，因此要指定注释文件格式：

`--annotation_format pgap `
`--annotation_format` 参数还支持其他多种来源的注释文件:

```SH
genbank - GenBank (default) # Genbank 下载的注释文件
bakta - Bakta: rapid & standardized annotation of bacterial genomes, MAGs & plasmids #bakta注释结果
microscope - Microbial Genome Annotation & Analysis Platform # microscope注释结果
patric - Pathosystems Resource Integration Center / BV-BRC # patric 在线注释结果
pseudomonasdb - The Pseudomonas Genome Database
rast - Rapid Annotation using Subsystem Technology # rast 在线注释结果
```

（1）仅使用蛋白质序列搜索：
```SH
amrfinder --plus -p  RA-RCAD.faa -g RA-RCAD_amrfinder.gff  --annotation_format prokka  --threads 8  -o RA-RCAD_AMRFinder_out_aa.xls
# 参数含义
# --plus 加强模式，提供来自“Plus”基因的结果，例如毒力因子、应激反应基因等。
# -p RA-RCAD.faa 输入蛋白序列文件
# -g RA-RCAD_amrfinder.gff 输入gff格式的基因组注释文件
# --threads 8 8核心cpu 用于加快速度 默认使用4 线程运算
# -o RA-RCAD_AMRFinder_out_aa.xls 检索结果输出到RA-RCAD_AMRFinder_out_aa.xls文件
```
（2）仅使用核苷酸搜索：
```SH
amrfinder --plus -n  RA-RCAD.ffn --annotation_format prokka  --threads 8  -o  RA-RCAD_AMRFinder_out_nuc.xls
# -n  RA-RCAD.ffn 输入CDS核酸序列文件
# --threads 8 8核心cpu 用于加快速度 默认使用4 线程运算
# -o RA-RCAD_AMRFinder_out_aa.xls 检索结果输出到RA-RCAD_AMRFinder_out_nuc.xls文件
```
（3）组合搜索：
```SH
amrfinder --plus -n  RA-RCAD.ffn -p  RA-RCAD.faa -g RA-RCAD_amrfinder.gff  --annotation_format prokka --threads 8  -o RA-RCAD_AMRFinder_out_all.xls
# --plus 加强模式，提供来自“Plus”基因的结果，例如毒力因子、应激反应基因等。
# -p RA-RCAD.faa 输入蛋白序列文件
# -n  RA-RCAD.ffn 输入CDS核酸序列文件
# -g RA-RCAD_amrfinder.gff 输入gff格式的基因组注释文件
# --threads 8 8核心cpu 用于加快速度 默认使用4 线程运算
# -o RA-RCAD_AMRFinder_out_all.xls 检索结果输出到RA-RCAD_AMRFinder_out_all.xls文件
更多参数及用法，详见：https://github.com/ncbi/amr/wiki
```
# 5、结果示例：
结果为制表符分割的表格（excel可打开），可以根据表头理解对应列的含义，一般关注红框信息部分。