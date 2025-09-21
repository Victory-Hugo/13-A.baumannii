# !/bin/bash
# 先准备gff文件列表

OUTPUT_DIR=/data_ssd3/7_luolintao_Baoman/1-Assemble/NCBI_Origin/Spacedust/
mkdir -p ${OUTPUT_DIR}

cat > ${OUTPUT_DIR}/gffDir.txt << 'EOF'
/data_ssd3/7_luolintao_Baoman/1-Assemble/NCBI_Origin/prokka/GCA_040009085.1/GCA_040009085.1.gff
/data_ssd3/7_luolintao_Baoman/1-Assemble/NCBI_Origin/prokka/GCA_040009735.1/GCA_040009735.1.gff
EOF
