#!/usr/bin/env python3
"""
鲍曼不动杆菌ERR197551基因组组装质量评估
"""

def analyze_assembly_quality():
    """评估组装质量"""
    
    print("🧬 " + "="*60)
    print("    鲍曼不动杆菌 ERR197551 EToKi 组装结果分析")
    print("="*62)
    
    # 分析contigs.fasta
    contigs_file = "ERR197551_assembly/spades/contigs.fasta"
    scaffolds_file = "ERR197551_assembly/spades/scaffolds.fasta"
    final_file = "ERR197551_assembly/etoki.mapping.reference.fasta"
    
    def get_assembly_stats(filename, description):
        sequences = []
        current_seq = ""
        
        with open(filename, 'r') as f:
            for line in f:
                line = line.strip()
                if line.startswith('>'):
                    if current_seq:
                        sequences.append(len(current_seq))
                    current_seq = ""
                else:
                    current_seq += line
            
            if current_seq:
                sequences.append(len(current_seq))
        
        sequences.sort(reverse=True)
        total_length = sum(sequences)
        num_contigs = len(sequences)
        
        # 计算N50
        cumulative_length = 0
        n50 = 0
        for length in sequences:
            cumulative_length += length
            if cumulative_length >= total_length * 0.5:
                n50 = length
                break
        
        print(f"\n📊 {description}")
        print(f"   Contigs数量: {num_contigs:,}")
        print(f"   总长度: {total_length:,} bp ({total_length/1e6:.2f} Mb)")
        print(f"   最长contig: {sequences[0]:,} bp")
        print(f"   N50: {n50:,} bp")
        print(f"   大于1kb的contigs: {sum(1 for x in sequences if x >= 1000)}")
        print(f"   大于10kb的contigs: {sum(1 for x in sequences if x >= 10000)}")
        
        return sequences, total_length, num_contigs, n50
    
    # 分析三个文件
    print("\n🔬 组装步骤对比:")
    contigs_seqs, contigs_total, contigs_num, contigs_n50 = get_assembly_stats(contigs_file, "Contigs (初步组装)")
    scaffolds_seqs, scaffolds_total, scaffolds_num, scaffolds_n50 = get_assembly_stats(scaffolds_file, "Scaffolds (scaffold化)")
    final_seqs, final_total, final_num, final_n50 = get_assembly_stats(final_file, "Final (EToKi处理后)")
    
    print("\n🎯 组装质量评估:")
    
    # 鲍曼不动杆菌基因组大小通常为3.8-4.2Mb
    expected_size = 4.0  # Mb
    print(f"   • 基因组大小: {final_total/1e6:.2f} Mb (预期: ~{expected_size} Mb)")
    
    size_ratio = (final_total/1e6) / expected_size
    if 0.95 <= size_ratio <= 1.05:
        print("     ✅ 基因组大小正常")
    elif size_ratio > 1.05:
        print("     ⚠️  基因组可能包含重复序列或污染")
    else:
        print("     ⚠️  基因组可能不完整")
    
    # N50评估
    print(f"   • N50: {final_n50:,} bp")
    if final_n50 > 50000:
        print("     ✅ N50良好")
    elif final_n50 > 20000:
        print("     ⚠️  N50中等，可以接受")
    else:
        print("     ❌ N50较低，组装碎片化严重")
    
    # Contigs数量评估
    print(f"   • Contigs数量: {final_num:,}")
    if final_num < 100:
        print("     ✅ Contigs数量很好")
    elif final_num < 500:
        print("     ⚠️  Contigs数量中等")
    else:
        print("     ❌ Contigs数量过多，组装碎片化")
    
    print("\n🏆 组装建议:")
    print("   1. 使用QUAST进行详细质量评估")
    print("   2. 用CheckM评估基因组完整性")
    print("   3. 使用Kraken2检测潜在污染")
    print("   4. 考虑基因注释和功能分析")
    
    print(f"\n📁 主要输出文件:")
    print(f"   • 最终组装: ERR197551_assembly/etoki.mapping.reference.fasta")
    print(f"   • SPAdes contigs: ERR197551_assembly/spades/contigs.fasta")
    print(f"   • SPAdes scaffolds: ERR197551_assembly/spades/scaffolds.fasta")
    print(f"   • 比对文件: ERR197551_assembly/etoki.mapping.merged.bam")

if __name__ == "__main__":
    analyze_assembly_quality()
