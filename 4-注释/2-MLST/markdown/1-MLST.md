# 介绍
什么是**MLST**?
多位点序列分型（MLST）是一种用于细菌分类和鉴定的分子生物学技术。它通过分析细菌基因组中多个保守基因的序列变异，来确定不同菌株之间的遗传关系。MLST的主要优点是其高分辨率和可重复性，使其成为流行病学研究和微生物监测的重要工具。

# 使用
首先登录官网：https://pubmlst.org/data
找到感兴趣的菌株，每种菌株的MLST信息都可以在其页面上找到，包括基因组序列、变异位点等信息。
注意，**鲍曼菌株**有2种分型标准，分别被称为**Oxford和Pasteur方案**。


| 方案      | 下载链接名称                      | 包含内容                                             |
| ------- | --------------------------------- | ---------------------------------------------------- |
| Oxford  | Acinetobacter baumannii#1profiles | Oxf\_gltA.fasta, Oxf\_gyrB.fasta, ..., profiles (ST) |
| Pasteur | Acinetobacter baumannii#2profiles | Pas\_gltA.fasta, Pas\_fusA.fasta, ..., profiles (ST) |

# 下载
官网上点击超链接即可下载。

# 整理
```SH
grep 'url' /mnt/f/OneDrive/文档（科研）/脚本/Download/13-A.baumannii/4-注释/2-MLST/conf/AB.xml \
    |awk -v FS='<url>' '{print $2}'\
    |awk -v FS='</url>' '{print $1}'\
    |grep -e 'fasta' -e 'csv' > \
    /mnt/f/OneDrive/文档（科研）/脚本/Download/13-A.baumannii/4-注释/2-MLST/conf/AB_url.txt
```

得到了`url`列表。