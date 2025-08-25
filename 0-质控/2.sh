
# 必要时再使用 Trimmomatic 进行数据清洗。
#! 双端测序数据
# 激活conda环境并运行trimmomatic
source ~/miniconda3/etc/profile.d/conda.sh
conda activate trimmomatic_env

trimmomatic PE -threads 4 \
  /mnt/c/Users/Administrator/Desktop/ERR197551/ERR197551_1.fastq.gz \
  /mnt/c/Users/Administrator/Desktop/ERR197551/ERR197551_2.fastq.gz \
  /mnt/c/Users/Administrator/Desktop/ERR197551_FQ/sample_R1.trim.fastq \
  /mnt/c/Users/Administrator/Desktop/ERR197551_FQ/sample_R1.unpaired.fastq \
  /mnt/c/Users/Administrator/Desktop/ERR197551_FQ/sample_R2.trim.fastq \
  /mnt/c/Users/Administrator/Desktop/ERR197551_FQ/sample_R2.unpaired.fastq \
  ILLUMINACLIP:$CONDA_PREFIX/share/trimmomatic-0.39-2/adapters/TruSeq3-PE.fa:2:30:10 \
  LEADING:5 TRAILING:5 \
  SLIDINGWINDOW:4:20 \
  MINLEN:50
#! 单端测序数据
# trimmomatic SE -threads 4 \
#   sample_SE.fastq \
#   sample_SE.trim.fastq \
#   ILLUMINACLIP:adapters.fa:2:30:10 \
#   LEADING:5 TRAILING:5 \
#   SLIDINGWINDOW:4:20 \
#   MINLEN:50