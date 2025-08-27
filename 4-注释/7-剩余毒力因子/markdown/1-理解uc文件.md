# UC文件
uc文件是`vsearch`软件的标准输出文件，包含了聚类分析的结果信息。

# 第一列
第一列只有3种可能：
1. S:Seed。
2. H:Hit。
3. C:Cluster。


## 如何理解？
S代表的是**种子**。即以这一行的这个基因序列为中心，形成**聚类中心**。
以`S	0	10356	*	*	*	*	*	SAMPLE_ERR1946991|INDDICEB_01503	*`为例，表示该序列是聚类**0**的种子序列。

H代表的是**命中序列**。即与种子序列相似度较高的其他序列，参与到该聚类中。
以`H	0	10356	100.0	+	0	0	=	SAMPLE_ERR1946999|INJDFNKL_00434	SAMPLE_ERR1946991|INDDICEB_01503`为例，表示该序列是聚类**0**的命中序列。

C代表的是**聚类信息**。即该聚类的统计信息。一般情况下，C行的序列都会在`uc`文件的前部分出现，因此不需要处理。如果某个 cluster 没有在 S 或 H 中出现（极少见情况，比如文件被截断或某些模式下），就用这行信息初始化 cluster_info，至少保证统计结果完整。

# 代码逻辑
```python
if record_type == 'S':
    cluster_id = int(fields[1])
    query_id = fields[8]
    clusters[cluster_id].append({'sequence_id': query_id, 'role': 'centroid', 'identity': 100.0})
    cluster_info[cluster_id] = {'centroid': query_id, 'size': 1}
```
S (Seed/Centroid)：表示某个聚类的种子序列。第2列是聚类编号 (cluster_id)，第9列是该 seed 序列 ID。程序在这里初始化这个 cluster。
→ 向 clusters 添加一个成员（role=centroid），并在 cluster_info 里存储聚类中心和大小。

```python
elif record_type == 'H':
    cluster_id = int(fields[1])
    query_id = fields[8]
    target_id = fields[9]
    clusters[cluster_id].append({'sequence_id': query_id, 'role': 'member', 'identity': identity, 'centroid': target_id})
    cluster_info[cluster_id]['size'] += 1
```
H (Hit/Member)：表示某个序列属于现有的某个 cluster，聚类编号在第2列。第9列是 query ID，第10列是对应的 centroid ID。
程序会追加这个成员，并更新 size。

# 举例
```sh
S	0	1	*	*	*	*	*	seqA	*
H	0	*	97.5	+	0	0	*	seqB	seqA
H	0	*	95.0	+	0	0	*	seqC	seqA
S	1	1	*	*	*	*	*	seqD	*
S	2	1	*	*	*	*	*	seqE	*
H	2	*	99.0	+	0	0	*	seqF	seqE
H	2	*	98.0	+	0	0	*	seqG	seqE
H	2	*	97.0	+	0	0	*	seqH	seqE
S	3	1	*	*	*	*	*	seqI	*
H	3	*	95.0	+	0	0	*	seqJ	seqI
H	3	*	94.0	+	0	0	*	seqK	seqI
H	3	*	93.0	+	0	0	*	seqL	seqI
H	3	*	92.0	+	0	0	*	seqM	seqI
H	3	*	91.0	+	0	0	*	seqN	seqI
H	3	*	90.0	+	0	0	*	seqO	seqI
H	3	*	89.0	+	0	0	*	seqP	seqI
```
首先看第二列的数字，该数字代表聚类编号（cluster_id）。例如第一行第二列：
cluster_id=0: 代表聚类编号为0.
S → seqA（centroid）种子序列
H → seqB, seqC 命中序列
→ cluster 0: [seqA, seqB, seqC]，大小=3

再来看第四行第二列：
cluster_id=1: 代表聚类编号为1.
S → seqD（没有 H），种子序列
→ cluster 1: [seqD]，大小=1

以此类推：
cluster_id=2: 代表聚类编号为2.
S → seqE（centroid）种子序列
H → seqF, seqG, seqH 命中序列
→ cluster 2: [seqE, seqF, seqG, seqH]，大小=4

cluster_id=3: 代表聚类编号为3.
S → seqI（centroid）种子序列
H → seqJ, seqK, seqL, seqM, seqN, seqO, seqP 命中序列
→ cluster 3: [seqI, seqJ, seqK, seqL, seqM, seqN, seqO, seqP]，大小=8