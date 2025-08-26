#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
MLST分型脚本 - 基于BLAST结果进行鲍曼菌ST分型

功能：
1. 解析BLAST比对结果（.b6格式）
2. 确定每个基因的最佳等位基因匹配
3. 根据等位基因组合确定ST型号
4. 生成详细的MLST分型报告

支持Oxford和Pasteur两种MLST方案

作者：GitHub Copilot
日期：2025-08-26
"""

import os
import sys
import csv
import argparse
from pathlib import Path
from collections import defaultdict, OrderedDict
from datetime import datetime

# MLST方案的基因列表
OXFORD_GENES = ['Oxf_gltA', 'Oxf_gyrB', 'Oxf_gdhB', 'Oxf_recA', 'Oxf_cpn60', 'Oxf_gpi', 'Oxf_rpoD']
PASTEUR_GENES = ['Pas_cpn60', 'Pas_fusA', 'Pas_gltA', 'Pas_pyrG', 'Pas_recA', 'Pas_rplB', 'Pas_rpoB']

# 质量控制阈值
MIN_IDENTITY = 95.0    # 最小相似度
MIN_COVERAGE = 90.0    # 最小覆盖度
MAX_EVALUE = 1e-10     # 最大E值


def parse_blast_results(blast_file):
    """
    解析BLAST结果文件
    
    返回格式：
    {
        'gene_name': [
            {
                'allele': 'allele_number',
                'identity': float,
                'coverage': float,
                'evalue': float,
                'score': float
            }, ...
        ]
    }
    """
    results = defaultdict(list)
    
    if not os.path.exists(blast_file):
        print(f"警告：BLAST结果文件不存在：{blast_file}")
        return results
    
    with open(blast_file, 'r') as f:
        for line in f:
            if line.strip():
                fields = line.strip().split('\t')
                if len(fields) >= 12:
                    # BLAST输出格式：qseqid sseqid pident length qlen slen qstart qend sstart send bitscore evalue
                    # 注意：实际输出中字段顺序可能不同，需要检查
                    query_id = fields[0]
                    subject_id = fields[1]
                    identity = float(fields[2])
                    length = int(fields[3])
                    
                    # 尝试解析其他字段，处理可能的格式问题
                    try:
                        qlen = int(fields[4]) if fields[4] != '0' else None
                        slen = int(fields[5]) if fields[5] != '0' else None
                        
                        # 如果前面的字段为0，尝试从其他位置获取
                        if qlen is None or qlen == 0:
                            # 尝试从query coordinates计算长度
                            qstart = int(fields[6]) if len(fields) > 6 else 1
                            qend = int(fields[7]) if len(fields) > 7 else length
                            qlen = abs(qend - qstart) + 1
                        
                        if slen is None or slen == 0:
                            slen = int(fields[8]) if len(fields) > 8 else length
                        
                        # E值和分数可能在不同位置
                        if len(fields) >= 12:
                            evalue = float(fields[10])
                            bitscore = float(fields[11])
                        else:
                            evalue = float(fields[-1])  # 最后一个字段
                            bitscore = float(fields[-2])  # 倒数第二个字段
                        
                    except (ValueError, IndexError) as e:
                        print(f"警告：解析BLAST结果行时出错：{line.strip()}")
                        continue
                    
                    # 计算覆盖度（基于查询序列长度）
                    # 注意：有些BLAST输出中qlen可能为0，需要特殊处理
                    if qlen > 0:
                        coverage = (length / qlen) * 100
                    else:
                        # 如果qlen为0，使用slen作为参考
                        coverage = (length / slen) * 100 if slen > 0 else 100.0
                    
                    # 提取基因名和等位基因号
                    if '_' in subject_id:
                        parts = subject_id.rsplit('_', 1)
                        if len(parts) == 2:
                            gene_name = parts[0]
                            allele_num = parts[1]
                            
                            results[gene_name].append({
                                'allele': allele_num,
                                'identity': identity,
                                'coverage': coverage,
                                'evalue': evalue,
                                'score': bitscore,
                                'length': length,
                                'qlen': qlen
                            })
    
    # 对每个基因的结果按照分数排序
    for gene in results:
        results[gene].sort(key=lambda x: (-x['score'], x['evalue'], -x['identity']))
    
    return dict(results)


def find_best_allele(blast_results, gene_name):
    """
    为指定基因找到最佳等位基因匹配
    
    返回：(allele_number, quality_info) 或 (None, error_message)
    """
    if gene_name not in blast_results:
        return None, f"未找到{gene_name}的BLAST结果"
    
    hits = blast_results[gene_name]
    if not hits:
        return None, f"{gene_name}无有效比对结果"
    
    # 筛选通过质量控制的结果
    valid_hits = []
    for hit in hits:
        if (hit['identity'] >= MIN_IDENTITY and 
            hit['coverage'] >= MIN_COVERAGE and 
            hit['evalue'] <= MAX_EVALUE):
            valid_hits.append(hit)
    
    if not valid_hits:
        return None, f"{gene_name}无满足质量标准的比对结果 (身份≥{MIN_IDENTITY}%, 覆盖度≥{MIN_COVERAGE}%, E值≤{MAX_EVALUE})"
    
    # 选择最佳匹配
    best_hit = valid_hits[0]
    
    # 检查是否有完美匹配（100%相似度和覆盖度）
    perfect_matches = [hit for hit in valid_hits if hit['identity'] == 100.0 and hit['coverage'] >= 99.0]
    
    quality_info = {
        'allele': best_hit['allele'],
        'identity': best_hit['identity'],
        'coverage': best_hit['coverage'],
        'evalue': best_hit['evalue'],
        'is_perfect': len(perfect_matches) > 0 and best_hit in perfect_matches,
        'alternative_alleles': len([h for h in valid_hits if h['identity'] >= 99.0]) - 1
    }
    
    return best_hit['allele'], quality_info


def read_profiles_csv(csv_file):
    """
    读取MLST配置文件（TSV格式，制表符分隔）
    """
    profiles = []
    if not os.path.exists(csv_file):
        return profiles
    
    with open(csv_file, 'r', newline='', encoding='utf-8') as f:
        reader = csv.DictReader(f, delimiter='\t')  # 使用制表符分隔
        for row in reader:
            # 清理空白字符
            cleaned_row = {k: v.strip() if v else v for k, v in row.items()}
            profiles.append(cleaned_row)
    
    return profiles


def determine_st_type_partial(allele_profile, profiles_file, scheme_name, min_genes=5):
    """
    根据等位基因组合确定ST型号（支持部分匹配）
    
    Args:
        allele_profile: 已知的等位基因字典
        profiles_file: MLST配置文件路径
        scheme_name: 方案名称 ('Oxford' 或 'Pasteur')
        min_genes: 最少需要匹配的基因数
    """
    if not os.path.exists(profiles_file):
        return None, f"配置文件不存在：{profiles_file}"
    
    try:
        # 读取ST配置文件
        profiles = read_profiles_csv(profiles_file)
        if not profiles:
            return None, f"无法读取配置文件：{profiles_file}"
        
        # 确保列名正确
        gene_columns = OXFORD_GENES if scheme_name == 'Oxford' else PASTEUR_GENES
        
        # 检查必需的列是否存在
        if profiles:
            available_columns = profiles[0].keys()
            missing_columns = [col for col in gene_columns if col not in available_columns]
            if missing_columns:
                return None, f"配置文件缺少列：{missing_columns}"
        
        # 查找最佳匹配的ST
        best_matches = []
        for profile in profiles:
            match_count = 0
            total_available = 0
            matched_genes = {}
            
            for gene in gene_columns:
                if gene in allele_profile and allele_profile[gene] is not None:
                    total_available += 1
                    expected_allele = str(allele_profile[gene]).strip()
                    actual_allele = str(profile.get(gene, '')).strip()
                    if expected_allele == actual_allele:
                        match_count += 1
                        matched_genes[gene] = expected_allele
            
            # 如果匹配的基因数达到要求
            if match_count >= min_genes and match_count == total_available:
                confidence = 'exact_match' if match_count == len(gene_columns) else 'partial_match'
                
                # 预测缺失基因的等位基因
                missing_genes = {}
                for gene in gene_columns:
                    if gene not in allele_profile or allele_profile[gene] is None:
                        missing_genes[gene] = profile.get(gene, 'N/A')
                
                best_matches.append({
                    'st': profile.get('ST', 'Unknown'),
                    'clonal_complex': profile.get('clonal_complex', 'N/A'),
                    'species': profile.get('species', 'N/A'),
                    'confidence': confidence,
                    'matched_count': match_count,
                    'total_genes': len(gene_columns),
                    'matched_genes': matched_genes,
                    'missing_genes': missing_genes
                })
        
        if best_matches:
            # 按匹配数排序，选择最佳匹配
            best_matches.sort(key=lambda x: x['matched_count'], reverse=True)
            best_match = best_matches[0]
            
            return best_match['st'], best_match
        
        return None, f"未找到至少匹配{min_genes}个基因的ST型号"
            
    except Exception as e:
        return None, f"处理配置文件时出错：{e}"


def analyze_sample(sample_name, blast_dir, profiles_dir):
    """
    分析单个样本的MLST分型
    """
    results = {
        'sample': sample_name,
        'oxford': {'st': None, 'alleles': {}, 'quality': {}, 'error': None},
        'pasteur': {'st': None, 'alleles': {}, 'quality': {}, 'error': None}
    }
    
    # 分析Oxford方案
    oxford_blast_file = os.path.join(blast_dir, f"{sample_name}.oxford_vs_query.b6")
    if os.path.exists(oxford_blast_file):
        oxford_results = parse_blast_results(oxford_blast_file)
        oxford_alleles = {}
        oxford_quality = {}
        
        for gene in OXFORD_GENES:
            allele, quality_info = find_best_allele(oxford_results, gene)
            if allele is not None:
                oxford_alleles[gene] = allele
                oxford_quality[gene] = quality_info
            else:
                oxford_quality[gene] = {'error': quality_info}
        
        results['oxford']['alleles'] = oxford_alleles
        results['oxford']['quality'] = oxford_quality
        
        # 确定ST型号（允许部分匹配，至少需要5个基因）
        if len(oxford_alleles) >= 5:
            oxford_profiles = os.path.join(profiles_dir, "Oxford", "profiles_oxford.csv")
            st_type, st_info = determine_st_type_partial(oxford_alleles, oxford_profiles, 'Oxford', min_genes=5)
            results['oxford']['st'] = st_type
            results['oxford']['st_info'] = st_info
        else:
            results['oxford']['error'] = f"找到的等位基因数量不足({len(oxford_alleles)}/7)，需要至少5个基因"
    else:
        results['oxford']['error'] = f"Oxford BLAST结果文件不存在：{oxford_blast_file}"
    
    # 分析Pasteur方案
    pasteur_blast_file = os.path.join(blast_dir, f"{sample_name}.pasteur_vs_query.b6")
    if os.path.exists(pasteur_blast_file):
        pasteur_results = parse_blast_results(pasteur_blast_file)
        pasteur_alleles = {}
        pasteur_quality = {}
        
        for gene in PASTEUR_GENES:
            allele, quality_info = find_best_allele(pasteur_results, gene)
            if allele is not None:
                pasteur_alleles[gene] = allele
                pasteur_quality[gene] = quality_info
            else:
                pasteur_quality[gene] = {'error': quality_info}
        
        results['pasteur']['alleles'] = pasteur_alleles
        results['pasteur']['quality'] = pasteur_quality
        
        # 确定ST型号（允许部分匹配，至少需要5个基因）
        if len(pasteur_alleles) >= 5:
            pasteur_profiles = os.path.join(profiles_dir, "Pasteur", "profiles_pasteur.csv")
            st_type, st_info = determine_st_type_partial(pasteur_alleles, pasteur_profiles, 'Pasteur', min_genes=5)
            results['pasteur']['st'] = st_type
            results['pasteur']['st_info'] = st_info
        else:
            results['pasteur']['error'] = f"找到的等位基因数量不足({len(pasteur_alleles)}/7)，需要至少5个基因"
    else:
        results['pasteur']['error'] = f"Pasteur BLAST结果文件不存在：{pasteur_blast_file}"
    
    return results


def generate_report(all_results, output_dir):
    """
    生成MLST分型报告
    """
    os.makedirs(output_dir, exist_ok=True)
    
    # 生成详细报告
    detailed_report_file = os.path.join(output_dir, "MLST_detailed_report.txt")
    with open(detailed_report_file, 'w', encoding='utf-8') as f:
        f.write("=" * 80 + "\n")
        f.write("鲍曼菌 MLST 分型详细报告\n")
        f.write("=" * 80 + "\n\n")
        f.write(f"分析时间：{datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n")
        f.write(f"质量控制标准：\n")
        f.write(f"  - 最小相似度：{MIN_IDENTITY}%\n")
        f.write(f"  - 最小覆盖度：{MIN_COVERAGE}%\n")
        f.write(f"  - 最大E值：{MAX_EVALUE}\n\n")
        
        for result in all_results:
            f.write("-" * 60 + "\n")
            f.write(f"样本：{result['sample']}\n")
            f.write("-" * 60 + "\n")
            
            # Oxford方案
            f.write("\n【Oxford方案】\n")
            if result['oxford']['st']:
                f.write(f"ST型号：ST-{result['oxford']['st']}\n")
                if 'st_info' in result['oxford']:
                    st_info = result['oxford']['st_info']
                    f.write(f"克隆复合群：{st_info.get('clonal_complex', 'N/A')}\n")
                    f.write(f"种属：{st_info.get('species', 'N/A')}\n")
                    f.write(f"匹配可信度：{st_info.get('confidence', 'N/A')}\n")
                    if st_info.get('confidence') == 'partial_match':
                        f.write(f"匹配基因数：{st_info.get('matched_count', 0)}/{st_info.get('total_genes', 7)}\n")
                
                f.write("\n等位基因组合：\n")
                for gene in OXFORD_GENES:
                    allele = result['oxford']['alleles'].get(gene, 'N/A')
                    quality = result['oxford']['quality'].get(gene, {})
                    if 'error' not in quality:
                        f.write(f"  {gene}: {allele} (相似度:{quality.get('identity', 0):.1f}%, 覆盖度:{quality.get('coverage', 0):.1f}%)\n")
                    else:
                        # 显示预测的等位基因（如果有部分匹配）
                        if 'st_info' in result['oxford'] and 'missing_genes' in result['oxford']['st_info']:
                            predicted = result['oxford']['st_info']['missing_genes'].get(gene)
                            if predicted and predicted != 'N/A':
                                f.write(f"  {gene}: 未检测到，预测为 {predicted}\n")
                            else:
                                f.write(f"  {gene}: 失败 - {quality['error']}\n")
                        else:
                            f.write(f"  {gene}: 失败 - {quality['error']}\n")
            else:
                f.write(f"ST型号：未确定\n")
                f.write(f"错误：{result['oxford'].get('error', '未知错误')}\n")
            
            # Pasteur方案
            f.write("\n【Pasteur方案】\n")
            if result['pasteur']['st']:
                f.write(f"ST型号：ST-{result['pasteur']['st']}\n")
                if 'st_info' in result['pasteur']:
                    st_info = result['pasteur']['st_info']
                    f.write(f"克隆复合群：{st_info.get('clonal_complex', 'N/A')}\n")
                    f.write(f"种属：{st_info.get('species', 'N/A')}\n")
                    f.write(f"匹配可信度：{st_info.get('confidence', 'N/A')}\n")
                    if st_info.get('confidence') == 'partial_match':
                        f.write(f"匹配基因数：{st_info.get('matched_count', 0)}/{st_info.get('total_genes', 7)}\n")
                
                f.write("\n等位基因组合：\n")
                for gene in PASTEUR_GENES:
                    allele = result['pasteur']['alleles'].get(gene, 'N/A')
                    quality = result['pasteur']['quality'].get(gene, {})
                    if 'error' not in quality:
                        f.write(f"  {gene}: {allele} (相似度:{quality.get('identity', 0):.1f}%, 覆盖度:{quality.get('coverage', 0):.1f}%)\n")
                    else:
                        # 显示预测的等位基因（如果有部分匹配）
                        if 'st_info' in result['pasteur'] and 'missing_genes' in result['pasteur']['st_info']:
                            predicted = result['pasteur']['st_info']['missing_genes'].get(gene)
                            if predicted and predicted != 'N/A':
                                f.write(f"  {gene}: 未检测到，预测为 {predicted}\n")
                            else:
                                f.write(f"  {gene}: 失败 - {quality['error']}\n")
                        else:
                            f.write(f"  {gene}: 失败 - {quality['error']}\n")
            else:
                f.write(f"ST型号：未确定\n")
                f.write(f"错误：{result['pasteur'].get('error', '未知错误')}\n")
            
            f.write("\n")
    
    # 生成简要汇总表
    summary_file = os.path.join(output_dir, "MLST_summary.csv")
    with open(summary_file, 'w', newline='', encoding='utf-8') as f:
        fieldnames = ['Sample', 'Oxford_ST', 'Oxford_CC', 'Oxford_Species', 
                     'Pasteur_ST', 'Pasteur_CC', 'Pasteur_Species', 'Status']
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        
        for result in all_results:
            row = {
                'Sample': result['sample'],
                'Oxford_ST': f"ST-{result['oxford']['st']}" if result['oxford']['st'] else 'N/A',
                'Oxford_CC': result['oxford'].get('st_info', {}).get('clonal_complex', 'N/A') if result['oxford']['st'] else 'N/A',
                'Oxford_Species': result['oxford'].get('st_info', {}).get('species', 'N/A') if result['oxford']['st'] else 'N/A',
                'Pasteur_ST': f"ST-{result['pasteur']['st']}" if result['pasteur']['st'] else 'N/A',
                'Pasteur_CC': result['pasteur'].get('st_info', {}).get('clonal_complex', 'N/A') if result['pasteur']['st'] else 'N/A',
                'Pasteur_Species': result['pasteur'].get('st_info', {}).get('species', 'N/A') if result['pasteur']['st'] else 'N/A',
                'Status': 'Complete' if (result['oxford']['st'] and result['pasteur']['st']) else 'Incomplete'
            }
            writer.writerow(row)
    
    print(f"\n报告已生成：")
    print(f"  详细报告：{detailed_report_file}")
    print(f"  汇总表格：{summary_file}")


def main():
    parser = argparse.ArgumentParser(description='鲍曼菌MLST分型脚本')
    parser.add_argument('-i', '--input', required=True,
                       help='BLAST结果目录（包含*.oxford_vs_query.b6和*.pasteur_vs_query.b6文件）')
    parser.add_argument('-p', '--profiles', required=True,
                       help='MLST配置文件目录（包含Oxford和Pasteur子目录）')
    parser.add_argument('-o', '--output', required=True,
                       help='输出目录')
    parser.add_argument('-s', '--samples', nargs='*',
                       help='指定要分析的样本名称（不包含扩展名），如果不指定则分析所有样本')
    parser.add_argument('--min-identity', type=float, default=95.0,
                       help='最小相似度阈值（默认：95.0）')
    parser.add_argument('--min-coverage', type=float, default=90.0,
                       help='最小覆盖度阈值（默认：90.0）')
    
    args = parser.parse_args()
    
    # 更新全局阈值
    global MIN_IDENTITY, MIN_COVERAGE
    MIN_IDENTITY = args.min_identity
    MIN_COVERAGE = args.min_coverage
    
    # 检查输入目录
    if not os.path.exists(args.input):
        print(f"错误：输入目录不存在：{args.input}")
        sys.exit(1)
    
    if not os.path.exists(args.profiles):
        print(f"错误：配置文件目录不存在：{args.profiles}")
        sys.exit(1)
    
    # 确定要分析的样本
    samples = args.samples
    if not samples:
        # 自动发现样本
        samples = set()
        for file in os.listdir(args.input):
            if file.endswith('.oxford_vs_query.b6'):
                sample_name = file.replace('.oxford_vs_query.b6', '')
                samples.add(sample_name)
            elif file.endswith('.pasteur_vs_query.b6'):
                sample_name = file.replace('.pasteur_vs_query.b6', '')
                samples.add(sample_name)
        samples = sorted(list(samples))
    
    if not samples:
        print("错误：未找到要分析的样本")
        sys.exit(1)
    
    print(f"发现 {len(samples)} 个样本需要分析：{', '.join(samples)}")
    print(f"质量控制标准：相似度≥{MIN_IDENTITY}%, 覆盖度≥{MIN_COVERAGE}%")
    print("-" * 60)
    
    # 分析所有样本
    all_results = []
    for sample in samples:
        print(f"正在分析样本：{sample}")
        result = analyze_sample(sample, args.input, args.profiles)
        all_results.append(result)
        
        # 简要显示结果
        oxford_st = f"ST-{result['oxford']['st']}" if result['oxford']['st'] else "未确定"
        pasteur_st = f"ST-{result['pasteur']['st']}" if result['pasteur']['st'] else "未确定"
        print(f"  Oxford: {oxford_st}   Pasteur: {pasteur_st}")
    
    # 生成报告
    generate_report(all_results, args.output)
    
    print(f"\n分析完成！共处理 {len(samples)} 个样本。")


if __name__ == '__main__':
    main()
