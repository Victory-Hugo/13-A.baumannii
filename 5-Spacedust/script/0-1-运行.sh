#!/bin/bash
#*=====第一步======
#* 参数配置区
#todo 运行前切换conda activate spacedust
conda activate spacedust
JOBNAME="Test"  #todo 作业名称
INPUT_TYPE=1  #todo 选择1：全对全比对；0：Target比对
SEARCH_TYPE=0  #todo 搜索模式：选择MMseqs 
NEED_PRODIGAL="True"
TARGET_TYPE=1 #todo TARGET_TYPE=0自己上传，1使用keggclusterdb 
MAX_GENE_GAP=3
NUM_ITERATIONS=1

#* 软件设置区域
BASEDIR="/mnt/f/OneDrive/文档（科研）/脚本/Download/13-A.baumannii/5-Spacedust/"
PRODIGAL="${BASEDIR}/download/prodigal.linux" 
KEGG_DATABASE_DIR="/mnt/e/Scientifc_software/KEGG_70"  #todo KEGG数据库路径
#* 路径设置区
INPUT_DIR="${BASEDIR}/${JOBNAME}_Prodigal"  #TODO 输入蛋白质序列目录
DATABASE_DIR="${BASEDIR}/database"
OUTPUT_DIR="${BASEDIR}/output"

echo "开始运行 Spacedust 流程 - 作业名称: ${JOBNAME}"
cd ${BASEDIR} || { echo "错误: 无法进入目录 ${BASEDIR}"; exit 1; }
mkdir -p ${DATABASE_DIR} tmp ${INPUT_DIR}


if [ "${NEED_PRODIGAL}" = "True" ]; then
  echo "开始使用 Prodigal 进行基因预测..."
  shopt -s nullglob
  fna_files=( ${JOBNAME}/*.fna )
  [ ${#fna_files[@]} -eq 0 ] && { echo "错误: 在 ${JOBNAME}/ 目录中没有找到 .fna 文件"; exit 1; }
  
  echo "找到 ${#fna_files[@]} 个 .fna 文件"
  
  for filename in ${JOBNAME}/*.fna; do
    base=$(basename "$filename" .fna)
    echo "处理文件: $filename -> ${base}.faa"
    
    $PRODIGAL \
      -i "$filename" \
      -a "${INPUT_DIR}/${base}.faa" \
      -f gff \
      -o "${INPUT_DIR}/${base}.gff" || {
      echo "  错误: Prodigal 处理失败"
      exit 1
    }
    echo "  成功生成: ${INPUT_DIR}/${base}.faa"
  done
  if [ "${INPUT_TYPE}" = "0" ] && [ "${TARGET_TYPE}" = "0" ]; then
    echo "处理目标文件..."
    for filename in ${JOBNAME}_target/*.fna; do
      base=$(basename "$filename" .fna)
      $PRODIGAL -i "$filename" -a "${JOBNAME}_target/${base}.faa" -f gff -o "${JOBNAME}_target/${base}.gff" || {
        echo "  错误: Prodigal 处理目标文件失败"
        exit 1
      }
      echo "  成功生成: ${JOBNAME}_target/${base}.faa"
    done
  fi
  shopt -u nullglob
  echo "Prodigal 基因预测完成！"
fi

# 检查生成的 .faa 文件
faa_files=( ${INPUT_DIR}/*.faa )
[ ${#faa_files[@]} -eq 0 ] && { echo "错误: 没有找到生成的 .faa 文件"; exit 1; }
echo "找到 ${#faa_files[@]} 个 .faa 文件"

echo "开始创建 Spacedust 数据库..."
spacedust createsetdb ${INPUT_DIR}/*.faa ${DATABASE_DIR}/${JOBNAME} tmp -v 0 || {
  echo "错误: spacedust createsetdb 失败"
  exit 1
}
echo "数据库创建成功: ${DATABASE_DIR}/${JOBNAME}"

echo "开始执行聚类搜索..."
if [ "${INPUT_TYPE}" = "1" ]; then
  echo "执行 all-against-all 搜索模式..."
  spacedust clustersearch ${DATABASE_DIR}/${JOBNAME} ${DATABASE_DIR}/${JOBNAME} "${JOBNAME}_result" tmp \
    --filter-self-match --search-mode "${SEARCH_TYPE}" --max-gene-gap "${MAX_GENE_GAP}" -v 1 || {
    echo "错误: spacedust clustersearch 失败"
    exit 1
  }
else
  if [ "${TARGET_TYPE}" = "0" ]; then
    echo "创建目标数据库..."
    spacedust createsetdb ${JOBNAME}_target/*.faa ${DATABASE_DIR}/${JOBNAME}_db tmp -v 0 || {
      echo "错误: 创建目标数据库失败"
      exit 1
    }

    spacedust clustersearch ${DATABASE_DIR}/${JOBNAME} ${DATABASE_DIR}/${JOBNAME}_db "${JOBNAME}_result" tmp \
      --search-mode "${SEARCH_TYPE}" --max-gene-gap "${MAX_GENE_GAP}" -v 1 || {
      echo "错误: spacedust clustersearch 失败"
      exit 1
    }
  else
    echo "使用 KEGG 数据库进行搜索..."
    spacedust clustersearch ${DATABASE_DIR}/${JOBNAME} ${KEGG_DATABASE_DIR}/keggclusterdb "${JOBNAME}_result" tmp \
      --search-mode "${SEARCH_TYPE}" --max-gene-gap "${MAX_GENE_GAP}" -v 1 || {
      echo "错误: spacedust clustersearch 失败"
      exit 1
    }
  fi
fi
echo "聚类搜索完成！"

echo "开始处理聚类结果..."
spacedust prefixid tmp/latest/clusters "${JOBNAME}_pref" --tsv -v 0 || {
  echo "错误: spacedust prefixid 失败"
  exit 1
}

echo "提取聚类信息..."
awk '{ print $2"\t"$3 }' "${JOBNAME}_pref" > qid_tid
awk '{ print $1 }' "${JOBNAME}_pref" > cluid
rm "${JOBNAME}_pref"


echo "转换序列名称..."
awk 'BEGIN{OFS=FS="\t"} NR==FNR{clr[$1]=$2; next} {$1=clr[$1]; print}' \
  ${DATABASE_DIR}/${JOBNAME}.lookup qid_tid > tmp_qname
if [ "${INPUT_TYPE}" = "1" ]; then
  awk 'BEGIN{OFS=FS="\t"} NR==FNR{clr[$1]=$2; next} {$2=clr[$2]; print}' \
    ${DATABASE_DIR}/${JOBNAME}.lookup tmp_qname > qname_tname
elif [ "${TARGET_TYPE}" = "0" ]; then
  awk 'BEGIN{OFS=FS="\t"} NR==FNR{clr[$1]=$2; next} {$2=clr[$2]; print}' \
    ${DATABASE_DIR}/${JOBNAME}_db.lookup tmp_qname > qname_tname
else
  awk 'BEGIN{OFS=FS="\t"} NR==FNR{clr[$1]=$2; next} {$2=clr[$2]; print}' \
  ${KEGG_DATABASE_DIR}/keggclusterdb.lookup tmp_qname > qname_tname
fi

echo "格式化序列名称..."
sed -i 's/NZ_/NZ./g' qname_tname
sed -i 's/NC_/NC./g' qname_tname
tr '_' '\t' < qname_tname > qname_tname_sep
rm tmp_qname qname_tname

echo "处理序列集合信息..."
awk 'BEGIN{OFS=FS="\t"} NR==FNR{clr[$1]=$3; next} {$1=clr[$1]; print}' \
  ${DATABASE_DIR}/${JOBNAME}.lookup qid_tid > tmp_qset
if [ "${INPUT_TYPE}" = "1" ]; then
  awk 'BEGIN{OFS=FS="\t"} NR==FNR{clr[$1]=$3; next} {$2=clr[$2]; print}' \
    ${DATABASE_DIR}/${JOBNAME}.lookup tmp_qset > qset_tset
elif [ "${TARGET_TYPE}" = "0" ]; then
  awk 'BEGIN{OFS=FS="\t"} NR==FNR{clr[$1]=$3; next} {$2=clr[$2]; print}' \
    ${DATABASE_DIR}/${JOBNAME}_db.lookup tmp_qset > qset_tset
else
  awk 'BEGIN{OFS=FS="\t"} NR==FNR{clr[$1]=$3; next} {$2=clr[$2]; print}' \
  ${KEGG_DATABASE_DIR}/keggclusterdb.lookup tmp_qset > qset_tset
fi
rm tmp_qset

echo "生成最终结果文件..."
paste cluid qset_tset qid_tid qname_tname_sep > "${JOBNAME}_plot"
rm qid_tid qname_tname_sep qset_tset cluid

echo "生成输入序列前缀信息..."
spacedust prefixid ${DATABASE_DIR}/${JOBNAME} ${DATABASE_DIR}/${JOBNAME}_pref --tsv -v 0 || {
  echo "错误: 生成输入序列前缀信息失败"
  exit 1
}

echo "所有处理步骤完成！"

echo "开始整理输出文件..."
mkdir -p ${OUTPUT_DIR}/{results,logs,database}

echo "移动结果文件到输出目录..."
mv "${JOBNAME}_plot" ${OUTPUT_DIR}/results/
[ -f "${JOBNAME}_result" ] && mv "${JOBNAME}_result" ${OUTPUT_DIR}/results/

echo "复制数据库文件..."
cp ${DATABASE_DIR}/${JOBNAME}.lookup ${OUTPUT_DIR}/database/ 2>/dev/null
cp ${DATABASE_DIR}/${JOBNAME}_pref ${OUTPUT_DIR}/database/ 2>/dev/null
cp ${DATABASE_DIR}/${JOBNAME}.source ${OUTPUT_DIR}/database/ 2>/dev/null


echo "清理中间文件..."
rm -rf tmp/ ${DATABASE_DIR} ${INPUT_DIR}
rm -f ${JOBNAME}.* ${JOBNAME}_result_seq_to_clu.* ${JOBNAME}.index.*
rm -f qid_tid cluid tmp_qname qname_tname tmp_qset qset_tset qname_tname_sep 2>/dev/null

echo ""
echo "🎉 Spacedust 分析完成！"
echo "最终输出目录: ${OUTPUT_DIR}/"
echo "主要结果文件: ${OUTPUT_DIR}/results/${JOBNAME}_plot"
