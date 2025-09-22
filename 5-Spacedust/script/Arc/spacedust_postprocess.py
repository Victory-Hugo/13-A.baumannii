#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
Spacedust 结果后处理脚本
功能：处理Spacedust运行后的结果文件，进行数据格式转换和整理
作者：整理自Jupyter notebook
"""

import os
import sys
import argparse
import pandas as pd
import logging
from pathlib import Path

# 设置日志
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    datefmt='%Y-%m-%d %H:%M:%S'
)
logger = logging.getLogger(__name__)

class SpacedustPostProcessor:
    """Spacedust结果后处理器"""
    
    def __init__(self, jobname, input_mode, target_db, workdir):
        self.jobname = jobname
        self.input_mode = input_mode
        self.target_db = target_db
        self.workdir = Path(workdir)
        
        # 设置文件路径
        self.pref_file = self.workdir / f"{jobname}_pref"
        self.result_file = self.workdir / jobname
        self.plot_file = self.workdir / f"{jobname}_plot"
        
        # 数据库路径
        self.input_lookup = self.workdir / "database" / f"{jobname}_input.lookup"
        self.target_lookup = self.workdir / "database" / f"{jobname}_db.lookup"
        self.kegg_lookup = self.workdir / "database" / "KEGG_70" / "keggclusterdb.lookup"
        
        # 处理参数
        self.input_type = 1 if input_mode == "all-against-all" else 0
        self.target_type = 0 if target_db == "self-uploaded" else 1
    
    def check_files(self):
        """检查必要的输入文件是否存在"""
        logger.info("检查输入文件...")
        
        if not self.pref_file.exists():
            raise FileNotFoundError(f"前缀文件不存在: {self.pref_file}")
        
        if not self.input_lookup.exists():
            raise FileNotFoundError(f"输入lookup文件不存在: {self.input_lookup}")
        
        # 检查目标lookup文件
        if self.input_type == 0:  # query-target模式
            if self.target_type == 0:  # 自上传数据库
                if not self.target_lookup.exists():
                    raise FileNotFoundError(f"目标lookup文件不存在: {self.target_lookup}")
            else:  # KEGG数据库
                if not self.kegg_lookup.exists():
                    raise FileNotFoundError(f"KEGG lookup文件不存在: {self.kegg_lookup}")
        
        logger.info("所有必要文件检查完成")
    
    def load_pref_data(self):
        """加载前缀数据"""
        logger.info("加载前缀数据...")
        
        try:
            # 读取前缀文件
            pref_df = pd.read_csv(
                self.pref_file, 
                sep='\t', 
                header=None, 
                names=['cluid', 'qid', 'tid']
            )
            
            logger.info(f"加载了 {len(pref_df)} 行前缀数据")
            return pref_df
            
        except Exception as e:
            logger.error(f"加载前缀数据失败: {e}")
            raise
    
    def load_lookup_data(self):
        """加载lookup数据"""
        logger.info("加载lookup数据...")
        
        try:
            # 加载输入lookup
            lookup_df = pd.read_csv(
                self.input_lookup, 
                sep='\t', 
                header=None, 
                names=['id', 'header', 'setid']
            )
            
            lookup_data = {'input': lookup_df}
            
            # 加载目标lookup（根据模式）
            if self.input_type == 1:  # all-against-all
                lookup_data['target'] = lookup_df  # 使用相同的lookup
            elif self.target_type == 0:  # 自上传目标
                target_lookup_df = pd.read_csv(
                    self.target_lookup, 
                    sep='\t', 
                    header=None, 
                    names=['id', 'header', 'setid']
                )
                lookup_data['target'] = target_lookup_df
            else:  # KEGG数据库
                kegg_lookup_df = pd.read_csv(
                    self.kegg_lookup, 
                    sep='\t', 
                    header=None, 
                    names=['id', 'header', 'setid']
                )
                lookup_data['target'] = kegg_lookup_df
            
            logger.info("Lookup数据加载完成")
            return lookup_data
            
        except Exception as e:
            logger.error(f"加载lookup数据失败: {e}")
            raise
    
    def create_name_mappings(self, lookup_data):
        """创建名称映射字典"""
        logger.info("创建名称映射...")
        
        # 查询名称映射
        input_lookup = lookup_data['input']
        qname_map = dict(zip(input_lookup['id'], input_lookup['header']))
        qset_map = dict(zip(input_lookup['id'], input_lookup['setid']))
        
        # 目标名称映射
        target_lookup = lookup_data['target']
        tname_map = dict(zip(target_lookup['id'], target_lookup['header']))
        tset_map = dict(zip(target_lookup['id'], target_lookup['setid']))
        
        mappings = {
            'qname_map': qname_map,
            'qset_map': qset_map,
            'tname_map': tname_map,
            'tset_map': tset_map
        }
        
        logger.info("名称映射创建完成")
        return mappings
    
    def process_data(self, pref_df, mappings):
        """处理数据，添加名称和位置信息"""
        logger.info("处理数据...")
        
        try:
            # 提取基本信息
            qid_tid = pref_df[['qid', 'tid']].copy()
            cluid = pref_df[['cluid']].copy()
            
            # 添加名称映射
            qid_tid['qname'] = qid_tid['qid'].map(mappings['qname_map'])
            qid_tid['tname'] = qid_tid['tid'].map(mappings['tname_map'])
            
            # 添加setid映射
            qid_tid['qsetid'] = qid_tid['qid'].map(mappings['qset_map'])
            qid_tid['tsetid'] = qid_tid['tid'].map(mappings['tset_map'])
            
            # 处理名称组件分离
            # 处理查询名称
            qname_processed = (qid_tid['qname']
                             .str.replace('NZ_', 'NZ.', regex=False)
                             .str.replace('NC_', 'NC.', regex=False)
                             .str.split('_', expand=True))
            
            if qname_processed.shape[1] >= 5:
                qid_tid[['qname_base', 'qid_p', 'qid_num', 'qstart', 'qend']] = qname_processed.iloc[:, :5]
            else:
                # 如果分割后列数不够，用默认值填充
                qid_tid['qname_base'] = qname_processed.iloc[:, 0] if qname_processed.shape[1] > 0 else ''
                qid_tid['qid_p'] = qname_processed.iloc[:, 1] if qname_processed.shape[1] > 1 else ''
                qid_tid['qid_num'] = qname_processed.iloc[:, 2] if qname_processed.shape[1] > 2 else ''
                qid_tid['qstart'] = qname_processed.iloc[:, 3] if qname_processed.shape[1] > 3 else ''
                qid_tid['qend'] = qname_processed.iloc[:, 4] if qname_processed.shape[1] > 4 else ''
            
            # 处理目标名称
            tname_processed = (qid_tid['tname']
                             .str.replace('NZ_', 'NZ.', regex=False)
                             .str.replace('NC_', 'NC.', regex=False)
                             .str.split('_', expand=True))
            
            if tname_processed.shape[1] >= 4:
                qid_tid[['tname_base', 'tid_num', 'tstart', 'tend']] = tname_processed.iloc[:, :4]
            else:
                # 如果分割后列数不够，用默认值填充
                qid_tid['tname_base'] = tname_processed.iloc[:, 0] if tname_processed.shape[1] > 0 else ''
                qid_tid['tid_num'] = tname_processed.iloc[:, 1] if tname_processed.shape[1] > 1 else ''
                qid_tid['tstart'] = tname_processed.iloc[:, 2] if tname_processed.shape[1] > 2 else ''
                qid_tid['tend'] = tname_processed.iloc[:, 3] if tname_processed.shape[1] > 3 else ''
            
            # 组合最终结果
            result_df = pd.concat([
                cluid,
                qid_tid[['qsetid', 'tsetid', 'qid', 'tid']],
                qid_tid[['qname_base', 'qid_p', 'qid_num', 'qstart', 'qend', 
                        'tname_base', 'tid_num', 'tstart', 'tend']]
            ], axis=1)
            
            logger.info(f"数据处理完成，共 {len(result_df)} 行")
            return result_df
            
        except Exception as e:
            logger.error(f"数据处理失败: {e}")
            raise
    
    def save_results(self, result_df):
        """保存处理结果"""
        logger.info("保存结果...")
        
        try:
            # 保存plot文件
            result_df.to_csv(
                self.plot_file, 
                sep='\t', 
                header=False, 
                index=False
            )
            
            logger.info(f"结果已保存到: {self.plot_file}")
            
            # 生成统计信息
            self.generate_statistics(result_df)
            
        except Exception as e:
            logger.error(f"保存结果失败: {e}")
            raise
    
    def generate_statistics(self, result_df):
        """生成统计信息"""
        logger.info("生成统计信息...")
        
        try:
            stats = {}
            stats['total_matches'] = len(result_df)
            stats['unique_clusters'] = result_df['cluid'].nunique()
            stats['unique_query_proteins'] = result_df['qid'].nunique()
            stats['unique_target_proteins'] = result_df['tid'].nunique()
            stats['unique_query_genomes'] = result_df['qsetid'].nunique()
            stats['unique_target_genomes'] = result_df['tsetid'].nunique()
            
            # 保存统计信息
            stats_file = self.workdir / f"{self.jobname}_statistics.txt"
            with open(stats_file, 'w', encoding='utf-8') as f:
                f.write("Spacedust 分析统计结果\n")
                f.write("=" * 30 + "\n")
                f.write(f"任务名称: {self.jobname}\n")
                f.write(f"输入模式: {self.input_mode}\n")
                f.write(f"目标数据库: {self.target_db}\n")
                f.write("-" * 30 + "\n")
                f.write(f"总匹配数: {stats['total_matches']:,}\n")
                f.write(f"唯一聚类数: {stats['unique_clusters']:,}\n")
                f.write(f"唯一查询蛋白质数: {stats['unique_query_proteins']:,}\n")
                f.write(f"唯一目标蛋白质数: {stats['unique_target_proteins']:,}\n")
                f.write(f"唯一查询基因组数: {stats['unique_query_genomes']:,}\n")
                f.write(f"唯一目标基因组数: {stats['unique_target_genomes']:,}\n")
            
            logger.info(f"统计信息已保存到: {stats_file}")
            
            # 打印统计信息
            logger.info("=== 分析统计 ===")
            for key, value in stats.items():
                logger.info(f"{key}: {value:,}")
            
        except Exception as e:
            logger.error(f"生成统计信息失败: {e}")
    
    def cleanup_temp_files(self):
        """清理临时文件"""
        logger.info("清理临时文件...")
        
        temp_files = ['qid_tid', 'cluid']
        for temp_file in temp_files:
            temp_path = self.workdir / temp_file
            if temp_path.exists():
                temp_path.unlink()
                logger.info(f"删除临时文件: {temp_file}")
        
        # 删除前缀文件
        if self.pref_file.exists():
            self.pref_file.unlink()
            logger.info(f"删除前缀文件: {self.pref_file}")
    
    def run(self):
        """运行完整的后处理流程"""
        logger.info("开始Spacedust结果后处理...")
        logger.info(f"任务名称: {self.jobname}")
        logger.info(f"输入模式: {self.input_mode}")
        logger.info(f"目标数据库: {self.target_db}")
        logger.info(f"工作目录: {self.workdir}")
        
        try:
            # 检查文件
            self.check_files()
            
            # 加载数据
            pref_df = self.load_pref_data()
            lookup_data = self.load_lookup_data()
            
            # 创建映射
            mappings = self.create_name_mappings(lookup_data)
            
            # 处理数据
            result_df = self.process_data(pref_df, mappings)
            
            # 保存结果
            self.save_results(result_df)
            
            # 清理临时文件
            self.cleanup_temp_files()
            
            logger.info("Spacedust结果后处理完成！")
            return True
            
        except Exception as e:
            logger.error(f"后处理失败: {e}")
            return False

def parse_arguments():
    """解析命令行参数"""
    parser = argparse.ArgumentParser(
        description='Spacedust结果后处理脚本',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog='''
示例用法:
  %(prog)s --jobname test --input-mode query-target --target-db KEGG_70 --workdir /path/to/work
  %(prog)s --jobname all_analysis --input-mode all-against-all --target-db self-uploaded --workdir ./
        '''
    )
    
    parser.add_argument(
        '--jobname', 
        required=True,
        help='任务名称'
    )
    
    parser.add_argument(
        '--input-mode', 
        required=True,
        choices=['query-target', 'all-against-all'],
        help='输入模式'
    )
    
    parser.add_argument(
        '--target-db', 
        required=True,
        choices=['KEGG_70', 'self-uploaded'],
        help='目标数据库类型'
    )
    
    parser.add_argument(
        '--workdir', 
        required=True,
        help='工作目录路径'
    )
    
    parser.add_argument(
        '--verbose', '-v',
        action='store_true',
        help='详细输出模式'
    )
    
    return parser.parse_args()

def main():
    """主函数"""
    try:
        # 解析参数
        args = parse_arguments()
        
        # 设置日志级别
        if args.verbose:
            logging.getLogger().setLevel(logging.DEBUG)
        
        # 检查工作目录
        workdir = Path(args.workdir)
        if not workdir.exists():
            logger.error(f"工作目录不存在: {workdir}")
            sys.exit(1)
        
        # 创建后处理器并运行
        processor = SpacedustPostProcessor(
            jobname=args.jobname,
            input_mode=args.input_mode,
            target_db=args.target_db,
            workdir=str(workdir)
        )
        
        success = processor.run()
        
        if success:
            logger.info("后处理成功完成")
            sys.exit(0)
        else:
            logger.error("后处理失败")
            sys.exit(1)
            
    except KeyboardInterrupt:
        logger.info("用户中断操作")
        sys.exit(1)
    except Exception as e:
        logger.error(f"程序异常: {e}")
        sys.exit(1)

if __name__ == '__main__':
    main()