
#todo 使用之前请先切换到conda环境安装prokka
#todo conda install prokka


prokka \
  --outdir /home/luolintao/5-AB-鲍曼/4-注释/ERR1946991_prokka \
  --prefix ERR1946991 \
  --force \
  --kingdom Bacteria \
  --genus Acinetobacter \
  --species baumannii \
  --strain ERR1946991 \
  --cpus 16 \
  /mnt/c/Users/Administrator/Desktop/ERR1946991.fasta
