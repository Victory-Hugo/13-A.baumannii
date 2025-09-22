#!/usr/bin/env Rscript

# Spacedust基因组上下文可视化R脚本 - 简化版本
# 使用基本ggplot2功能，避免单位错误

# 加载必要的库
library(ggplot2)
library(dplyr)

# 解析命令行参数
args <- commandArgs(trailingOnly = TRUE)

if (length(args) < 3) {
    cat("用法: Rscript visualize_genome_context_simple.R <input_csv> <output_dir> <center_gene>\n")
    cat("参数:\n")
    cat("  input_csv   - 输入的CSV数据文件\n")
    cat("  output_dir  - 输出目录\n")
    cat("  center_gene - 中心基因ID\n")
    quit(status = 1)
}

input_file <- args[1]
output_dir <- args[2]
center_gene <- args[3]

cat("基因组上下文可视化R脚本 - 简化版本\n")
cat("==========================\n")
cat(sprintf("输入文件: %s\n", input_file))
cat(sprintf("输出目录: %s\n", output_dir))
cat(sprintf("中心基因: %s\n", center_gene))

# 检查输入文件
if (!file.exists(input_file)) {
    cat(sprintf("错误: 输入文件不存在: %s\n", input_file))
    quit(status = 1)
}

# 创建输出目录
if (!dir.exists(output_dir)) {
    dir.create(output_dir, recursive = TRUE)
}

# 读取数据
cat("读取基因数据...\n")
gggene_df <- read.csv(input_file, stringsAsFactors = FALSE)
cat(sprintf("读取了 %d 行基因数据\n", nrow(gggene_df)))

if (nrow(gggene_df) == 0) {
    cat("错误: 数据文件为空\n")
    quit(status = 1)
}

cat("数据预览:\n")
print(head(gggene_df))

# 数据预处理
cat("处理基因数据...\n")

# 添加基因组标识
if (!"genome" %in% colnames(gggene_df)) {
    gggene_df$genome <- gggene_df$qname
}

# 添加基因方向
gggene_df$strand <- ifelse(gggene_df$qstart < gggene_df$qend, "forward", "reverse")

# 计算基因长度
gggene_df$length <- abs(gggene_df$qend - gggene_df$qstart)

# 标准化起始和结束位置
gggene_df$start <- pmin(gggene_df$qstart, gggene_df$qend)
gggene_df$end <- pmax(gggene_df$qstart, gggene_df$qend)

# 添加基因标签
gggene_df$gene_label <- paste0("gene_", gggene_df$qid)

# 标记中心基因
gggene_df$is_center <- gggene_df$qid == as.numeric(center_gene)

cat("数据处理完成\n")
cat(sprintf("包含 %d 个基因组\n", length(unique(gggene_df$genome))))
cat(sprintf("包含 %d 个基因\n", nrow(gggene_df)))

# 简化的基因组上下文图 - 使用基本ggplot2
cat("生成基因组上下文图...\n")

# 基础散点图版本
p1 <- ggplot(gggene_df, aes(x = start, y = genome)) +
    geom_point(aes(color = strand, size = length), alpha = 0.7) +
    geom_point(data = subset(gggene_df, is_center), 
               aes(x = start, y = genome), 
               color = "red", size = 4, shape = 17) +
    scale_color_manual(values = c("forward" = "blue", "reverse" = "orange")) +
    scale_size_continuous(range = c(1, 5)) +
    theme_minimal() +
    theme(
        axis.text.x = element_text(angle = 45, hjust = 1),
        strip.text = element_text(size = 10),
        legend.position = "bottom"
    ) +
    labs(title = sprintf("Genome Context - Center Gene: %s", center_gene),
         x = "Gene Position",
         y = "Genome",
         color = "Strand",
         size = "Gene Length") +
    facet_wrap(~ genome, scales = "free", ncol = 1)

# 保存基本图 - 使用png()而不是ggsave()
output_file1 <- file.path(output_dir, "spacedust_genome_context_simple.png")
png(output_file1, width = 1200, height = 800, res = 100)
print(p1)
dev.off()
cat(sprintf("基因组上下文图已保存: %s\n", output_file1))

# 创建基因密度图
if (length(unique(gggene_df$genome)) > 1) {
    p2 <- ggplot(gggene_df, aes(x = start)) +
        geom_histogram(aes(fill = strand), bins = 30, alpha = 0.7) +
        scale_fill_manual(values = c("forward" = "blue", "reverse" = "orange")) +
        theme_minimal() +
        labs(title = "Gene Density Distribution",
             x = "Gene Position",
             y = "Count",
             fill = "Strand") +
        facet_wrap(~ genome, scales = "free")
    
    output_file2 <- file.path(output_dir, "spacedust_gene_density.png")
    png(output_file2, width = 1200, height = 600, res = 100)
    print(p2)
    dev.off()
    cat(sprintf("基因密度图已保存: %s\n", output_file2))
}

# 统计图
if (nrow(gggene_df) > 0) {
    strand_stats <- gggene_df %>%
        group_by(genome, strand) %>%
        summarise(count = n(), .groups = "drop")
    
    p3 <- ggplot(strand_stats, aes(x = genome, y = count, fill = strand)) +
        geom_bar(stat = "identity", position = "dodge") +
        scale_fill_manual(values = c("forward" = "blue", "reverse" = "orange")) +
        theme_minimal() +
        theme(axis.text.x = element_text(angle = 45, hjust = 1)) +
        labs(title = "Gene Strand Distribution by Genome",
             x = "Genome",
             y = "Gene Count",
             fill = "Strand")
    
    output_file3 <- file.path(output_dir, "spacedust_strand_stats_simple.png")
    png(output_file3, width = 800, height = 600, res = 100)
    print(p3)
    dev.off()
    cat(sprintf("链方向统计图已保存: %s\n", output_file3))
}

# 保存处理后的数据
processed_data_file <- file.path(output_dir, "processed_gene_data_simple.csv")
write.csv(gggene_df, processed_data_file, row.names = FALSE)
cat(sprintf("处理后的数据已保存: %s\n", processed_data_file))

# 生成总结报告
summary_file <- file.path(output_dir, "genome_context_summary_simple.txt")
sink(summary_file)
cat("Spacedust基因组上下文可视化总结 (简化版本)\n")
cat("=========================================\n")
cat(sprintf("生成时间: %s\n", Sys.time()))
cat(sprintf("输入文件: %s\n", input_file))
cat(sprintf("中心基因: %s\n", center_gene))
cat(sprintf("基因组数量: %d\n", length(unique(gggene_df$genome))))
cat(sprintf("基因总数: %d\n", nrow(gggene_df)))
cat(sprintf("正向基因: %d\n", sum(gggene_df$strand == "forward")))
cat(sprintf("反向基因: %d\n", sum(gggene_df$strand == "reverse")))
cat(sprintf("中心基因数量: %d\n", sum(gggene_df$is_center)))
cat("\n基因组列表:\n")
for (genome in unique(gggene_df$genome)) {
    gene_count <- sum(gggene_df$genome == genome)
    cat(sprintf("  %s: %d genes\n", genome, gene_count))
}
sink()

cat(sprintf("总结报告已保存: %s\n", summary_file))

cat("\n==========================\n")
cat("R可视化完成！\n")
cat("生成的文件:\n")
if (exists("output_file1")) cat(sprintf("  - %s\n", basename(output_file1)))
if (exists("output_file2")) cat(sprintf("  - %s\n", basename(output_file2)))
if (exists("output_file3")) cat(sprintf("  - %s\n", basename(output_file3)))
cat(sprintf("  - %s\n", basename(processed_data_file)))
cat(sprintf("  - %s\n", basename(summary_file)))