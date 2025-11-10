#!/usr/bin/env python3
"""
综合数据处理脚本
用于批量处理毒力因子和生物杀灭抵抗数据

使用方法：
    python3 5-Batch_processing.py
"""

import subprocess
import sys
from pathlib import Path
import os

def check_dependencies():
    """检查依赖包"""
    try:
        import pandas as pd
        import numpy as np
        print("✓ 依赖包检查通过")
        return True
    except ImportError as e:
        print(f"❌ 缺少依赖包: {e}")
        print("请安装必要的包：")
        print("  pip install pandas numpy")
        return False

def run_script(script_path, input_file, output_dir):
    """运行脚本"""
    cmd = [sys.executable, str(script_path), str(input_file), str(output_dir)]
    print(f"\n🚀 运行: {' '.join(cmd)}")
    
    try:
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=3600)  # 1小时超时
        
        if result.returncode == 0:
            print(f"✅ 成功完成: {script_path.name}")
            print(result.stdout)
        else:
            print(f"❌ 脚本失败: {script_path.name}")
            print(f"错误信息: {result.stderr}")
            return False
        return True
    except subprocess.TimeoutExpired:
        print(f"⏰ 脚本超时: {script_path.name}")
        return False
    except Exception as e:
        print(f"💥 运行错误: {e}")
        return False

def main():
    print("="*60)
    print("📊 A. baumannii 综合数据处理系统")
    print("="*60)
    
    # 检查依赖
    if not check_dependencies():
        sys.exit(1)
    
    # 定义路径
    base_dir = Path("/mnt/f/OneDrive/文档（科研）/脚本/Download/13-A.baumannii/4-注释/8-结果整理")
    script_dir = base_dir / "script"
    data_dir = Path("/mnt/d/1-ABaumannii/1-注释汇总")
    
    # 定义处理任务
    tasks = [
        {
            'name': '毒力因子数据处理',
            'script': script_dir / "3-Virulence_format_conversion.py",
            'input': data_dir / "input/毒力因子_合并.csv",
            'output': data_dir / "2-NCBI-Sequence/virulence_output"
        },
        {
            'name': '生物杀灭抵抗数据处理',
            'script': script_dir / "4-Biocide_format_conversion.py",
            'input': data_dir / "input/生物杀灭抵抗_合并.csv",
            'output': data_dir / "2-NCBI-Sequence/biocide_output"
        }
    ]
    
    # 执行处理任务
    results = []
    for task in tasks:
        print(f"\n{'='*40}")
        print(f"📋 开始处理: {task['name']}")
        print(f"📂 输入文件: {task['input']}")
        print(f"📁 输出目录: {task['output']}")
        
        # 检查输入文件
        if not task['input'].exists():
            print(f"❌ 输入文件不存在: {task['input']}")
            results.append(False)
            continue
        
        # 创建输出目录
        task['output'].mkdir(parents=True, exist_ok=True)
        
        # 运行脚本
        success = run_script(task['script'], task['input'], task['output'])
        results.append(success)
    
    # 输出总结
    print("\n" + "="*60)
    print("📊 处理总结")
    print("="*60)
    
    for i, task in enumerate(tasks):
        status = "✅ 成功" if results[i] else "❌ 失败"
        print(f"{status} {task['name']}")
    
    total_success = sum(results)
    print(f"\n总计: {total_success}/{len(tasks)} 个任务完成")
    
    if total_success == len(tasks):
        print("\n🎉 所有任务完成！")
        print("\n📂 输出文件位置:")
        for task in tasks:
            print(f"  - {task['name']}: {task['output']}")
    else:
        print("\n⚠️  部分任务失败，请检查错误信息")

if __name__ == "__main__":
    main()