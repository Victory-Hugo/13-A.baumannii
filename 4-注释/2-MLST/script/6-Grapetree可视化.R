library(ggtree)
library(treeio)
library(tidyverse)

# 设置工作目录
setwd("/mnt/d/1-鲍曼菌/MLST/分型结果")
# 加载树文件
WGS_tree <- read.tree("MLST_ST_Ox.tree.nwk")
WGS_tree

ggtree(WGS_tree,layout = "radial" ,aes(color = branch.length), lwd = 2) +
    geom_tiplab(size = 5, align = TRUE, hjust = -0.5) #* 添加tiplab，默认显示`label`

