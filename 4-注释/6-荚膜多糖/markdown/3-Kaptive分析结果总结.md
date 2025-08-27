# Kaptive荚膜多糖类型分析结果总结

## 分析概述

使用Kaptive v2.0.3对鲍曼不动杆菌（*Acinetobacter baumannii*）的OCL（外膜多糖）和K locus（荚膜多糖）类型进行了预测分析。

**分析日期：** $(date +"%Y-%m-%d %H:%M:%S")  
**分析样本：** ERR1946991, ERR1946999  
**输入数据：** 基因组组装文件 (.fasta)  
**分析工具：** Kaptive v2.0.3  

## 分析结果

### 1. OCL类型分析结果

| 样本 | 最佳匹配基因座 | 类型 | 置信度 | 覆盖度 | 一致性 | 预期基因数 |
|------|---------------|------|---------|--------|--------|-----------|
| ERR1946991 | OCL1 | **OC1** | Typeable | 98.88% | 100.00% | 9/9 (100%) |
| ERR1946999 | OCL1 | **OC1** | Typeable | 98.88% | 100.00% | 9/9 (100%) |

**结论：** 两个样本均被鉴定为 **OC1** 型外膜多糖，具有高置信度和完整的基因组成。

### 2. K locus类型分析结果

| 样本 | 最佳匹配基因座 | 类型 | 置信度 | 覆盖度 | 一致性 | 预期基因数 | 问题 |
|------|---------------|------|---------|--------|--------|-----------|------|
| ERR1946991 | KL3 | **K3-v1** | Typeable | 99.46% | 99.54% | 20/20 (100%) | ?2! |
| ERR1946999 | KL3 | **K3** | Typeable | 99.49% | 99.58% | 20/20 (100%) | ! |

**结论：** 两个样本均被鉴定为 **K3** 型荚膜多糖：
- ERR1946991: K3-v1变异型
- ERR1946999: K3标准型

### 3. 基因组成分析

#### OCL1基因组成（9个基因）：
1. `OCL1_01_gtrOC1` - 糖基转移酶
2. `OCL1_02_gtrOC2` - 糖基转移酶  
3. `OCL1_03_pda1` - 多糖脱乙酰酶
4. `OCL1_04_gtrOC3` - 糖基转移酶
5. `OCL1_05_gtrOC4` - 糖基转移酶
6. `OCL1_06_orf1(ghy)` - 糖水解酶
7. `OCL1_07_gtrOC5` - 糖基转移酶
8. `OCL1_08_gtrOC6` - 糖基转移酶
9. `OCL1_09_gtrOC7` - 糖基转移酶

#### KL3基因组成（20个基因）：
1. `KL3_01_wzc` - 调控蛋白
2. `KL3_02_wzb` - 磷酸酶
3. `KL3_03_wza` - 多糖输出蛋白
4. `KL3_04_gna3` - 糖核苷酰基转移酶
5. `KL3_05_dgaA` - N-乙酰氨基糖-1-磷酸转移酶
6. `KL3_06_dgaB` - N,N'-二乙酰壳寡糖脱乙酰酶
7. `KL3_07_dgaC` - N-乙酰氨基糖激酶
8. `KL3_08_wzx_KL3` - 翻转酶 (部分截断)
9. `KL3_09_atr2` - 氨基转移酶
10. `KL3_10_gtr6` - 糖基转移酶 (ERR1946991中截断)
11. `KL3_11_gtr7` - 糖基转移酶
12. `KL3_12_wzy_KL3` - 聚合酶
13. `KL3_13_gtr8` - 糖基转移酶
14. `KL3_14_gtr9` - 糖基转移酶
15. `KL3_15_itrA2` - 糖转移酶
16. `KL3_16_galU` - UTP-葡萄糖-1-磷酸尿苷酰转移酶
17. `KL3_17_ugd` - UDP-葡萄糖脱氢酶
18. `KL3_18_gpi` - 葡萄糖-6-磷酸异构酶
19. `KL3_19_gne1` - UDP-N-乙酰葡糖胺-4-差向异构酶
20. `KL3_20_pgm` - 磷酸葡糖变位酶

## 文件输出

### 输出目录结构：
```
/mnt/f/OneDrive/文档（科研）/脚本/Download/13-A.baumannii/4-注释/6-荚膜多糖/output/
├── OCL_results/
│   ├── ERR1946991_OCL_results.tsv
│   ├── ERR1946991_OCL_results.json
│   ├── ERR1946991_kaptive_results.fna
│   ├── ERR1946991_kaptive_results.png
│   ├── ERR1946999_OCL_results.tsv
│   ├── ERR1946999_OCL_results.json
│   ├── ERR1946999_kaptive_results.fna
│   └── ERR1946999_kaptive_results.png
├── K_locus_results/
│   ├── ERR1946991_K_locus_results.tsv
│   ├── ERR1946991_K_locus_results.json
│   ├── ERR1946991_kaptive_results.fna
│   ├── ERR1946991_kaptive_results.png
│   ├── ERR1946999_K_locus_results.tsv
│   ├── ERR1946999_K_locus_results.json
│   ├── ERR1946999_kaptive_results.fna
│   └── ERR1946999_kaptive_results.png
├── All_OCL_results.tsv
└── All_K_locus_results.tsv
```

### 文件说明：
- **`.tsv`文件：** 表格形式的详细分析结果
- **`.json`文件：** JSON格式的结构化结果数据
- **`.fna`文件：** 鉴定的荚膜多糖基因座序列
- **`.png`文件：** 基因座结构的可视化图表
- **`All_*_results.tsv`：** 所有样本的合并结果

## 临床意义

1. **OCL类型 OC1：** 外膜多糖类型，与鲍曼不动杆菌的血清型和毒力相关
2. **K locus类型 K3：** 荚膜多糖类型，影响细菌的致病性和免疫逃逸能力
3. **基因完整性：** 两个样本的荚膜多糖相关基因基本完整，提示具有完整的荚膜合成能力

## 使用的参数

- **数据库：** 
  - OCL分析：`ab_o` (Acinetobacter_baumannii_OC_locus_primary_reference)
  - K locus分析：`ab_k` (Acinetobacter_baumannii_k_locus_primary_reference)
- **线程数：** 自动检测（24核心）
- **最小覆盖度：** 50%（默认）
- **输出格式：** TSV, JSON, FASTA, PNG

---

*分析完成于：$(date +"%Y-%m-%d %H:%M:%S")*  
*生成工具：Kaptive v2.0.3*  
*分析脚本：1-Kaptive.sh*
