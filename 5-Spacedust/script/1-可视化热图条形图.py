#!/usr/bin/env python3
"""
Spacedust结果可视化脚本 - 忠实于原始notebook但移除rpy2依赖
这个版本保持原始逻辑但使用纯Python，R代码部分单独实现为R脚本

功能：
1. 加载和处理Spacedust数据（完全按照原始notebook）
2. 生成热图和条形图组合（完全按照原始notebook）
3. 生成滑动条形图（完全按照原始notebook）
4. 处理蛋白质选择和数据准备（为R脚本准备数据）
5. 输出数据文件供独立R脚本使用
"""

import os
import sys
import argparse
import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
import matplotlib.cm as cm
import matplotlib.ticker as ticker
from matplotlib.widgets import Slider
from pathlib import Path

def load_spacedust_data(jobname, data_dir="."):
    """
    加载Spacedust数据 - 完全按照原始notebook实现
    """
    print("准备可视化所需数据")
    
    # 检查依赖包 - 来自原始notebook（移除rpy2检查）
    import importlib
    missing = []
    for package, import_name in [("matplotlib", "matplotlib"), ("pandas", "pandas"), ("numpy", "numpy")]:
        try:
            importlib.import_module(import_name)
        except ImportError:
            missing.append(package)

    if missing:
        raise ImportError(f"缺少以下 Python 包，请先安装：{', '.join(missing)}")

    # 按照原始notebook读取数据
    plot_file = f"{data_dir}/results/{jobname}_plot"
    lookup_file = f"{data_dir}/database/{jobname}.lookup"
    pref_file = f"{data_dir}/database/{jobname}_pref"
    
    print(f"读取文件: {plot_file}")
    matchhit = pd.read_csv(plot_file, sep="\t", header=None)
    
    print(f"初始读取行数: {len(matchhit)}, 列数: {len(matchhit.columns)}")
    
    # 基于实际数据结构定义列名 - 17列
    if len(matchhit.columns) == 17:
        matchhit.columns = ['cluid','qsetid', 'tsetid', 'qseqid','tseqid',
                           'qname', 'qid_p','qid','qstart','qend','qend2', 
                           'tname','tid','tid2','tid3','tstart','tend']
    else:
        # 如果列数不同，使用原来的14列定义
        matchhit.columns = ['cluid','qsetid', 'tsetid', 'qseqid','tseqid',
                           'qname', 'qid_p','qid','qstart','qend', 
                           'tname','tid','tstart','tend'][:len(matchhit.columns)]
    
    # 确保数据类型正确
    numeric_columns = ['cluid', 'qsetid', 'tsetid', 'qseqid', 'tseqid', 'qid_p', 'qid', 'qend', 'tid', 'tstart', 'tend']
    for col in numeric_columns:
        if col in matchhit.columns:
            matchhit[col] = pd.to_numeric(matchhit[col], errors='coerce')
    
    # 特别处理qstart列
    if 'qstart' in matchhit.columns:
        matchhit['qstart'] = pd.to_numeric(matchhit['qstart'], errors='coerce')
    
    # 删除有NaN值的行
    before_dropna = len(matchhit)
    matchhit = matchhit.dropna()
    print(f"删除NaN后行数: {len(matchhit)} (删除了 {before_dropna - len(matchhit)} 行)")
    
    print(f"读取文件: {lookup_file}")
    lookup = pd.read_csv(lookup_file, sep="\t", 
                        names=['seqid','header','setid'])
    
    # 处理可能不存在的pref文件
    all_seq = None
    if os.path.exists(pref_file):
        print(f"读取文件: {pref_file}")
        all_seq = pd.read_csv(pref_file, sep="\t", 
                             names=['id','seq'], header=None, dtype={'id' : int, 'seq': str})
    else:
        print(f"警告: {pref_file} 不存在，跳过")
    
    return matchhit, lookup, all_seq

def select_query_genome(matchhit, lookup, data_dir, jobname, selected_query_genome_name=None):
    """
    选择查询基因组并构建索引 - 完全按照原始notebook实现
    """
    # 原始notebook的实现
    source_file = f'{data_dir}/database/{jobname}.source'
    print(f"读取源文件: {source_file}")
    
    df = pd.read_csv(source_file, sep="\t", 
                    names=['query_genome_id','query_genome_name'], 
                    dtype={'query_genome_id': int, 'query_genome_name': str})
    available = df['query_genome_name'].tolist()
    if not available:
        raise ValueError('未在 source 文件中找到任何基因组。')

    if selected_query_genome_name is None:
        chosen = available[0]
    elif selected_query_genome_name not in available:
        raise ValueError(f"selected_query_genome_name={selected_query_genome_name} 不在可选列表中: {available}")
    else:
        chosen = selected_query_genome_name

    selected_query_genome_name = chosen
    query_genome = int(df.loc[df['query_genome_name'] == chosen, 'query_genome_id'].iloc[0])
    print(f"使用查询基因组: {chosen} (ID={query_genome})")

    # 原始notebook的数据处理逻辑
    print(f"过滤前matchhit行数: {len(matchhit)}")
    print(f"查询基因组ID: {query_genome}")
    matchhit_temp = matchhit[matchhit['qsetid'] == query_genome]
    print(f"过滤后matchhit_temp行数: {len(matchhit_temp)}")
    
    qid = matchhit_temp.drop_duplicates(['qid','tsetid'], keep='last')['qid'].to_numpy()
    print(f"去重后qid数量: {len(qid)}")
    matchhit_array = np.zeros(qid.max()+1, dtype=int) if len(qid) else np.array([])
    for i in qid:
        matchhit_array[i] += 1

    ordered = matchhit.sort_values(['cluid', 'qid'])
    qid_all = ordered['qid'].to_numpy()
    tid_all = ordered['tid'].to_numpy()
    cluid_all = ordered['cluid'].to_numpy()
    
    max_qid = qid_all.max() if len(qid_all) > 0 else 0
    matchpair_array = np.zeros(max_qid + 1, dtype=int)
    
    for i in np.arange(len(qid_all)-1):
        if cluid_all[i] == cluid_all[i+1]:
            if qid_all[i] == qid_all[i+1] - 1:
                matchpair_array[qid_all[i]] += 1
            else:
                if abs(qid_all[i+1] - qid_all[i]) == abs(tid_all[i+1] - tid_all[i]):
                    for x in np.arange(qid_all[i], qid_all[i+1]):
                        if x < len(matchpair_array):
                            matchpair_array[x] += 1

    count = np.zeros(matchhit_array.max()+1) if matchhit_array.size else np.array([])
    for value in matchhit_array.tolist():
        count[value] += 1

    lookup_temp = lookup[lookup['setid'] == query_genome].copy()
    if len(lookup_temp) > 0:
        lookup_temp['idx'] = lookup_temp['header'].str.split('_').str[-3].astype(int)
        lookup_temp['qstart'] = lookup_temp['header'].str.split('_').str[-2].astype(int)
        lookup_temp['qend'] = lookup_temp['header'].str.split('_').str[-1].astype(int)
    
    return {
        'matchhit': matchhit,
        'matchhit_array': matchhit_array,
        'matchpair_array': matchpair_array,
        'lookup_temp': lookup_temp,
        'query_genome': query_genome,
        'chosen_genome': chosen
    }

def create_heatmap_barplot(data, output_dir, zoom=False, lower_bound=1, upper_bound=100):
    """
    集群匹配热图/条形图 - 完全按照原始notebook实现
    """
    print("生成热图/条形图组合")
    
    matchhit = data['matchhit']
    matchhit_array = data['matchhit_array']
    matchpair_array = data['matchpair_array']
    lookup_temp = data['lookup_temp']
    query_genome = data['query_genome']
    
    # 确保 lower_bound 始终小于 upper_bound - 原始notebook检查
    if lower_bound >= upper_bound:
        raise ValueError("Lower bound must be smaller than upper_bound")

    # 原始notebook的热图/条形图实现
    # 获取最大蛋白质ID和基因组ID
    max_protein_id = np.max(matchhit['qid']) if len(matchhit) > 0 else 0
    max_genome_id = np.max(matchhit['tsetid']) if len(matchhit) > 0 else 0

    # 创建正确大小的空矩阵
    matrix = np.zeros((max_genome_id + 1, max_protein_id + 1))
    matrix[query_genome,:] = 1
    # 用蛋白质匹配数据填充矩阵
    for _, row in matchhit.iterrows():
        matrix[row['tsetid'], row['qid']] = 1

    # 为链图创建空矩阵
    strand_plot = np.zeros(len(lookup_temp['idx']) if len(lookup_temp) > 0 else max_protein_id + 1, dtype=int)

    # 遍历基因数据框以标记正负链
    if len(lookup_temp) > 0:
        for _, row in lookup_temp.iterrows():
            if (row['qstart'] < row['qend']) and row['idx'] < len(strand_plot):
                # 将正链位置设为1
                strand_plot[row['idx']] = 1

    # 创建具有调整高度比的图形和轴
    fig, (ax1, ax3, ax2) = plt.subplots(nrows=3, sharex=True, figsize=(10, 12), 
                                       gridspec_kw={'height_ratios': [4, 0.1, 1]})

    # 创建热图
    heatmap = ax1.imshow(matrix, cmap='Blues', interpolation='none', aspect='auto')

    # 设置标题、y轴标签和y轴刻度标签
    ax1.set_title('Presence/Absence Heatmap')
    ax1.set_ylabel('Genome ID')
    y_labels = range(0, max_genome_id + 1)
    ax1.set_yticks(range(0, max_genome_id + 1))
    ax1.set_yticklabels(y_labels)

    # 使用AutoLocator根据缩放级别动态调整x轴刻度
    ax1.xaxis.set_major_locator(ticker.AutoLocator())

    # 使用AutoLocator根据缩放级别动态调整y轴刻度
    ax1.yaxis.set_major_locator(ticker.AutoLocator())

    # 设置x轴刻度标签和旋转
    x_labels = range(0, max_protein_id + 1)
    ax2.set_xticks(range(0, max_protein_id + 1))
    ax2.set_xticklabels(x_labels, rotation=90)

    # 在热图下方添加条形图
    if len(matchpair_array) > 0:
        ax2.bar(np.arange(len(matchpair_array)), matchpair_array, width=1, align='edge', 
                edgecolor='black', color='lightpink')
    if len(matchhit_array) > 0:
        ax2.bar(np.arange(len(matchhit_array)), matchhit_array, width=0.5, align='center')
    
    ax2.set_ylabel('Hits Count')
    ax2.set_xlabel('Query Protein Position Index')

    # 调整x轴的限制以匹配热图
    if zoom:
        ax2.set_xlim(lower_bound-0.5, upper_bound + 0.5)
    else:
        ax2.set_xlim(-0.5, max_protein_id+1 - 0.5)

    if len(matchhit_array) > 0 and np.max(matchhit_array) > 0:
        ax2.set_yscale('log')

    # 使用AutoLocator根据缩放级别动态调整x轴刻度
    ax2.xaxis.set_major_locator(ticker.AutoLocator())

    # 将链图添加为细线
    if len(strand_plot) > 0:
        cmap_binary = cm.binary
        ax3.imshow(strand_plot.reshape(1, -1), cmap=cmap_binary, aspect='auto')
    ax3.yaxis.set_ticks([])
    ax3.set_ylabel('Strand')

    # 启用交互模式
    plt.ion()

    # 缩放时调整图形大小的函数
    def on_zoom(event):
        current_xlim = ax1.get_xlim()
        current_ylim = ax1.get_ylim()
        current_ylim2 = ax2.get_ylim()
        ax1.set_xlim(*current_xlim)
        ax1.set_ylim(*current_ylim)
        ax2.set_ylim(*current_ylim2)
        ax3.set_xlim(*current_xlim)

    # 将on_zoom函数连接到缩放事件
    fig.canvas.mpl_connect('resize_event', on_zoom)

    # 保存图表到文件
    plt.tight_layout()
    
    # 保存图像
    safe_genome_name = data['chosen_genome'].replace('.', '_').replace('/', '_')
    zoom_suffix = f"_zoom_{lower_bound}-{upper_bound}" if zoom else ""
    
    pdf_path = os.path.join(output_dir, f'faithful_heatmap_{safe_genome_name}{zoom_suffix}.pdf')
    png_path = os.path.join(output_dir, f'faithful_heatmap_{safe_genome_name}{zoom_suffix}.png')
    
    plt.savefig(pdf_path)
    plt.savefig(png_path)
    plt.close()
    
    print(f"热图已保存: {pdf_path}, {png_path}")
    return pdf_path, png_path

def create_sliding_barplot(data, output_dir, N=100):
    """
    集群匹配条形图 - 完全按照原始notebook实现
    """
    print("生成滑动条形图")
    
    matchhit = data['matchhit']
    matchhit_array = data['matchhit_array']
    matchpair_array = data['matchpair_array']
    query_genome = data['query_genome']
    
    # 原始notebook中的qid计算
    qid = matchhit[matchhit['qsetid'] == query_genome].drop_duplicates(['qid','tsetid'], keep='last')['qid']
    
    # 原始notebook的条形图实现
    fig, ax = plt.subplots(figsize=(10,6))
    fig.patch.set_facecolor('white')

    # 原始notebook的数据准备
    x = np.arange(qid.max()+1) if len(qid) > 0 else np.array([0])
    y1 = matchhit_array
    y2 = matchpair_array

    # 原始notebook的bar函数实现（静态版本）
    def create_bar_plot(pos):
        pos = int(pos)
        ax.clear()
        if pos+N > len(x):
            n = len(x)-pos
        else:
            n = N
        X = x[pos:pos+n]
        Y = y1[pos:pos+n] if pos+n <= len(y1) else y1[pos:min(len(y1), pos+n)]
        Y2 = y2[pos:pos+n] if pos+n <= len(y2) else y2[pos:min(len(y2), pos+n)]
        
        if len(Y2) > 0:
            ax.bar(X[:len(Y2)], Y2, width=1, align='edge', edgecolor='black', color='lightgrey')
        if len(Y) > 0:
            ax.bar(X[:len(Y)], Y, width=0.5, align='edge', edgecolor='black')
        
        ax.set_title(f'Cluster matches bar plot (position {pos}-{pos+n-1})')
        ax.set_xlabel('Gene Position')
        ax.set_ylabel('Hit Count')

    # 创建第一个窗口的静态图
    create_bar_plot(0)
    
    # 保存静态图像
    safe_genome_name = data['chosen_genome'].replace('.', '_').replace('/', '_')
    output_path = os.path.join(output_dir, f'faithful_sliding_barplot_{safe_genome_name}.png')
    plt.savefig(output_path)
    plt.close()
    
    print(f"滑动条形图已保存: {output_path}")
    return output_path

def select_proteins_and_prepare_data(data, query_protein_id_input=None, output_dir='.'):
    """
    选择感兴趣的蛋白质，提取包含蛋白质编码基因的所有集群匹配
    准备数据供R脚本使用 - 完全按照原始notebook逻辑
    """
    print("处理蛋白质选择和数据准备")
    
    matchhit = data['matchhit']
    
    # 如果没有指定query_protein_id，使用第一个可用的qid
    if query_protein_id_input is None:
        if len(matchhit) > 0:
            query_protein_id_input = str(int(matchhit['qid'].min()))
            print(f"自动选择第一个可用的蛋白质ID: {query_protein_id_input}")
        else:
            print("没有可用的蛋白质数据")
            return pd.DataFrame(), None
    
    # 原始notebook的输入解析函数
    def parse_input(input_str):
        parts = input_str.split('-')
        if len(parts) == 1:
            # 单个整数
            return [int(parts[0])]
        elif len(parts) == 2:
            # 范围
            return list(range(int(parts[0]), int(parts[1]) + 1))
        else:
            raise ValueError("Invalid input format. Please enter either a single integer or a range.")

    # 打印范围内的所有数字
    query_protein_id = parse_input(query_protein_id_input)

    # 过滤clusterid以仅包含具有所有query_protein_ids的集群
    clusterid = matchhit.loc[matchhit['qid'].isin(query_protein_id), 'cluid'].unique().tolist()
    print(f"找到 {len(clusterid)} 个相关集群")

    # 检查每个集群中是否存在所有query_protein_ids
    filtered_clusterid = [cluster for cluster in clusterid if all(matchhit[matchhit['cluid'] == cluster]['qid'].isin(query_protein_id))]

    appended_data = pd.DataFrame()
    for i in clusterid:
        appended_data = pd.concat([appended_data, matchhit[matchhit['cluid'] == i]])

    print(f"appended_data形状: {appended_data.shape}")
    print(f"appended_data列: {list(appended_data.columns) if len(appended_data) > 0 else '空DataFrame'}")
    
    if len(appended_data) > 0 and 'qseqid' in appended_data.columns:
        appended_data = appended_data[appended_data['qseqid'].map(appended_data['qseqid'].value_counts()) > 1]
    else:
        print("警告: appended_data为空或缺少qseqid列")
        if len(appended_data) > 0:
            print(f"可用列: {list(appended_data.columns)}")
        return pd.DataFrame(), None

    # 原始notebook的数据处理逻辑
    predefined_qseqid = query_protein_id[0]

    def invert_sign(group):
        matching_rows = group[group['qseqid'] == predefined_qseqid]

        if not matching_rows.empty:
            predefined_row = matching_rows.iloc[0]
            q_direction = np.sign(predefined_row['qstart'] - predefined_row['qend'])
            t_direction = np.sign(predefined_row['tstart'] - predefined_row['tend'])

            if q_direction != t_direction:
                group['tstart'], group['tend'] = -group['tstart'].values, -group['tend'].values

        return group

    appended_data_g = appended_data.groupby('cluid', group_keys=False).apply(invert_sign)

    center = str(query_protein_id[0])
    appended_data_g = appended_data_g[appended_data_g['tname']!= appended_data_g['qname']]
    gggene_df = appended_data_g.groupby(by="qid", as_index = False).first()[['qname','qid','qstart','qend']]
    
    # 使用pd.concat替代已弃用的append
    additional_data = appended_data_g[['tname','qid','tstart','tend']].rename(columns={"tname": "qname", "tstart": "qstart","tend": "qend"})
    gggene_df = pd.concat([gggene_df, additional_data]).reset_index(drop=True)
    
    # 保存数据供R脚本使用
    output_file = os.path.join(output_dir, 'gggene_data_for_r.csv')
    gggene_df.to_csv(output_file, index=False)
    print(f"数据已保存供R脚本使用: {output_file}")
    
    return gggene_df, output_file

def main():
    parser = argparse.ArgumentParser(description='Spacedust结果可视化 - 忠实于原始Jupyter Notebook（纯Python版本）')
    parser.add_argument('--data-dir', '-d', default='/mnt/c/Users/Administrator/Desktop/output', 
                       help='Spacedust数据目录路径')
    parser.add_argument('--jobname', '-j', default='TEST', 
                       help='作业名称')
    parser.add_argument('--output-dir', '-o', default='/mnt/c/Users/Administrator/Desktop/output/image/faithful', 
                       help='输出图像目录')
    parser.add_argument('--genome', '-g', 
                       help='指定查询基因组名称')
    parser.add_argument('--zoom', action='store_true',
                       help='启用缩放')
    parser.add_argument('--lower-bound', type=int, default=1,
                       help='缩放下界（默认：1）')
    parser.add_argument('--upper-bound', type=int, default=100,
                       help='缩放上界（默认：100）')
    parser.add_argument('--query-protein-id', default='1',
                       help='查询蛋白质ID（单个整数或范围，例如 "1" 或 "1-10"）')
    parser.add_argument('--window-size', type=int, default=100,
                       help='滑动窗口大小（默认：100）')
    
    args = parser.parse_args()
    
    # 创建输出目录
    os.makedirs(args.output_dir, exist_ok=True)
    
    try:
        print("Spacedust结果可视化 - 忠实于原始Jupyter Notebook源代码（纯Python版本）")
        print("=" * 70)
        
        # 1. 加载数据
        print("1. 加载Spacedust数据...")
        matchhit, lookup, all_seq = load_spacedust_data(args.jobname, args.data_dir)
        
        # 2. 选择查询基因组并构建索引
        print("2. 选择查询基因组并构建索引...")
        data = select_query_genome(matchhit, lookup, args.data_dir, args.jobname, args.genome)
        print(f"数据检查 - matchhit行数: {len(data['matchhit'])}")
        if len(data['matchhit']) > 0:
            print(f"qid范围: {data['matchhit']['qid'].min()} - {data['matchhit']['qid'].max()}")
        else:
            print("警告: matchhit为空")
        
        # 3. 生成热图/条形图组合
        print("3. 生成集群匹配热图/条形图...")
        create_heatmap_barplot(data, args.output_dir, args.zoom, args.lower_bound, args.upper_bound)
        
        # 4. 生成滑动条形图
        print("4. 生成集群匹配条形图...")
        create_sliding_barplot(data, args.output_dir, args.window_size)
        
        # 5. 处理蛋白质选择和数据准备
        print("5. 处理蛋白质选择和数据准备...")
        protein_id = args.query_protein_id if args.query_protein_id != '1' else None
        gggene_df, data_file = select_proteins_and_prepare_data(data, protein_id, args.output_dir)
        print(f"处理了 {len(gggene_df)} 行基因数据")
        
        print("\n" + "=" * 70)
        print("Python可视化完成！")
        print(f"数据文件已准备完成: {data_file}")
        print("现在可以运行R脚本进行基因组上下文可视化。")
        
    except Exception as e:
        print(f"错误: {e}", file=sys.stderr)
        sys.exit(1)

if __name__ == '__main__':
    main()