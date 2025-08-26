# GrapeTree 使用说明

## 环境准备
已成功修复 pyg 环境中的依赖问题：
- 卸载了 etoki 包（解除 numpy 版本限制）
- 更新 numpy 到 1.24.4 版本
- 安装 pyarrow 包
- 现在 grapetree 可以正常运行

## 数据格式要求
grapetree 需要的输入文件格式：
- 文件使用制表符分隔（TSV 格式）
- 第一列：样本名称
- 其余列：各个基因座的等位基因编号
- 不需要标题行
- 文件扩展名可以是 .txt 或 .csv

示例格式：
```
ERR1946991	1	3	189	2	2	96	3
ERR1946999	1	4	189	2	2	96	3
Sample001	2	3	189	2	2	96	4
```

## 脚本使用
当前脚本 `5-.sh` 内容：
```bash
grapetree -p profiles_simple.txt > tree.nwk
```

## 替换真实数据步骤
1. 将您的 MLST 结果文件转换为上述格式
2. 保存为 `profiles_simple.txt` 或修改脚本中的文件名
3. 运行脚本：`bash 5-.sh`
4. 输出文件：`tree.nwk`（Newick 格式系统发育树）

## 输出说明
- 生成的 tree.nwk 文件是标准的 Newick 格式
- 可以用 FigTree、iTOL 等工具可视化
- 数字表示分支长度（等位基因差异数）

## 当前测试结果
使用模拟数据成功生成了系统发育树：
- 输入：10个样本的MLST数据
- 输出：tree.nwk 文件
- 树结构显示了样本间的遗传关系
