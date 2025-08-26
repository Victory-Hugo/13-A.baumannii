#!/bin/bash
# 此脚本用于批量计算参考基因组与指定目录下所有fasta文件的ANI（平均核苷酸相似性）。
# 
# 主要步骤如下：
# 1. 设置相关目录和文件路径变量，包括组装目录、fasta列表文件、输出结果文件和参考基因组fasta文件。
# 2. 切换到组装目录。
# 3. 查找组装目录下所有fasta文件（最大深度2），并将其路径写入列表文件。
# 4. 使用fastANI工具，计算参考基因组与列表中所有fasta文件的ANI值，并将结果输出到指定文件。
#
# 注意事项：
# - 需要预先安装fastANI工具。
# - 路径需根据实际环境进行调整。
# - 输出文件将包含每个样本与参考基因组的ANI结果。
#todo 设置目录和文件路径
ASSEMBLE_DIR="/data_raid/7_luolintao/1_Baoman/1-Assemble/" #? 组装目录
LIST_TXT="/home/luolintao/0_Github/13-A.baumannii/3-fastANI/conf/list.txt" #? fasta列表文件
OUTPUT_TXT="/home/luolintao/0_Github/13-A.baumannii/3-fastANI/output/OUT.TXT" #? 输出结果文件
REF_FASTA="/home/luolintao/0_Github/13-A.baumannii/3-fastANI/data/GCF_008632635.1.fasta" #? 参考基因组fasta文件

cd ${ASSEMBLE_DIR}


find $(pwd) -maxdepth 2 -type f -name "*fasta" > ${LIST_TXT}

fastANI \
    -q ${REF_FASTA} \
    --rl ${LIST_TXT} \
    -o ${OUTPUT_TXT}
