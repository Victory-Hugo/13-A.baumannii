#!/bin/bash

#*=====第一步======
#* 参数配置区
#todo 运行前切换conda activate spacedust
conda activate spacedust

INPUT_TYPE=1  #todo 选择1：全对全比对；0：Target比对
SEARCH_TYPE=0  #todo 搜索模式：选择MMseqs 
NEED_PRODIGAL="True"
TARGET_TYPE=1 #todo TARGET_TYPE=0自己上传，1使用keggclusterdb 
MAX_GENE_GAP=3
NUM_ITERATIONS=1

#*=========分隔符==========
JOBNAME="Test"  #! 作业名称
BASEDIR="/mnt/f/OneDrive/文档（科研）/脚本/Download/13-A.baumannii/5-Spacedust/" #? 脚本所在目录
WORK_DIR="/mnt/c/Users/Administrator/Desktop/Spa/" #! 工作目录
ORIGIN_DIR="/mnt/c/Users/Administrator/Desktop/Test/"  #! 输入基因组目录
PROCESSION_DIR="${WORK_DIR}/Test_Prodigal/"  #! 输入蛋白质序列目录，由prodigal生成
DATABASE_DIR="${WORK_DIR}/database" #! 数据库目录
OUTPUT_DIR="${WORK_DIR}/output" #! 输出目录
#*=========分隔符==========
PRODIGAL="/mnt/f/OneDrive/文档（科研）/脚本/Download/13-A.baumannii/5-Spacedust/download/prodigal.linux" 
#*=========分隔符==========
KEGG_DATABASE_DIR="/mnt/e/Scientifc_software/KEGG_70"  #! KEGG数据库路径
#*=========分隔符==========


cd ${BASEDIR} 
mkdir -p ${DATABASE_DIR} tmp ${PROCESSION_DIR}

# ---- 颜色定义（兼容 tput 与转义序列） ----
if command -v tput >/dev/null 2>&1 && [ -t 1 ]; then
  # 终端且支持 tput
  BLUE="$(tput setaf 4)"
  BOLD="$(tput bold)"
  RESET="$(tput sgr0)"
else
  # 兼容性回退（在不支持 tput 或非交互终端时不使用颜色）
  if [ -t 1 ]; then
    BLUE=$'\033[0;34m'
    BOLD=$'\033[1m'
    RESET=$'\033[0m'
  else
    BLUE=""
    BOLD=""
    RESET=""
  fi
fi

# ---- 便捷输出函数 ----
# cecho "文本"        -> 普通蓝色行
# cecho_bold "文本"   -> 加粗蓝色行
cecho() { printf "%b\n" "${BLUE}$*${RESET}"; }
cecho_bold() { printf "%b\n" "${BOLD}${BLUE}$*${RESET}"; }
cecho "开始运行 Spacedust 流程 - 作业名称: ${JOBNAME}"

cecho_bold "该脚本通过Jupyter Notebook转换而来"
cecho_bold "我只测试了全对全比对模式"
cecho_bold "KEGG暂未测试"

if [ "${NEED_PRODIGAL}" = "True" ]; then
  shopt -s nullglob

  for filename in "${ORIGIN_DIR}"/*.fna; do
    base=$(basename "$filename" .fna)
    "$PRODIGAL" \
      -i "$filename" \
      -a "${PROCESSION_DIR}/${base}.faa" \
      -f gff \
      -o "${PROCESSION_DIR}/${base}.gff"
  done

  if [ "${INPUT_TYPE}" = "0" ] && [ "${TARGET_TYPE}" = "0" ]; then
    for filename in "${PROCESSION_DIR}"/*.fna; do
      base=$(basename "$filename" .fna)
      "$PRODIGAL" -i "$filename" -a "${PROCESSION_DIR}/${base}.faa" -f gff -o "${PROCESSION_DIR}/${base}.gff"
    done
  fi

  shopt -u nullglob
fi


# 检查生成的 .faa 文件
faa_files=( ${PROCESSION_DIR}/*.faa )
[ ${#faa_files[@]} -eq 0 ] && { cecho "错误: 没有找到生成的 .faa 文件"; exit 1; }
cecho "[找到 ${#faa_files[@]} 个 .faa 文件]"

cecho "[开始创建 Spacedust 数据库]"
spacedust \
  createsetdb \
  ${PROCESSION_DIR}/*.faa \
  ${DATABASE_DIR}/${JOBNAME} \
  tmp -v 0 || \
  {
  cecho "[错误: spacedust createsetdb 失败]"
  exit 1
  }
cecho "[数据库创建成功,目前存放在: ${DATABASE_DIR}/${JOBNAME}]"


cecho "[现在进入工作目录${WORK_DIR}进行聚类搜索...]"
cd ${WORK_DIR}
cecho "[开始执行聚类搜索...]"
if [ "${INPUT_TYPE}" = "1" ]; then
  cecho "[执行 all-against-all 搜索模式...]"
  spacedust clustersearch \
  ${DATABASE_DIR}/${JOBNAME} \
  ${DATABASE_DIR}/${JOBNAME} \
  "Cluster" \
  tmp \
  --filter-self-match --search-mode "${SEARCH_TYPE}" \
  --max-gene-gap "${MAX_GENE_GAP}" \
  -v 1 || {
    cecho "[错误: spacedust clustersearch 失败]"
    exit 1
  }
else
  if [ "${TARGET_TYPE}" = "0" ]; then
    cecho "[创建目标数据库...]"
    spacedust \
    createsetdb \
    ${JOBNAME}_target/*.faa \
    ${DATABASE_DIR}/${JOBNAME}_db \
    tmp \
    -v 1 || {
    cecho "[错误: 创建目标数据库失败]"
    exit 1
    }
    spacedust \
    clustersearch \
    ${DATABASE_DIR}/${JOBNAME} \
    ${DATABASE_DIR}/${JOBNAME}_db \
    "${JOBNAME}_result" \
    tmp \
    --search-mode "${SEARCH_TYPE}" \
    --max-gene-gap "${MAX_GENE_GAP}" \
    -v 1 || {
    cecho "[错误: spacedust clustersearch 失败]"
    exit 1
    }
  else
    cecho "[使用 KEGG 数据库进行搜索]"
    spacedust \
    clustersearch \
    ${DATABASE_DIR}/${JOBNAME} \
    ${KEGG_DATABASE_DIR}/keggclusterdb \
    "${JOBNAME}_result" \
    tmp \
    --search-mode "${SEARCH_TYPE}" \
    --max-gene-gap "${MAX_GENE_GAP}" \
    -v 1 || {
    cecho "[错误: spacedust clustersearch 失败]"
    exit 1
    }
  fi
fi
cecho "[聚类搜索完成!]"

cecho "开始处理聚类结果..."
spacedust prefixid tmp/latest/clusters "${JOBNAME}_pref" --tsv -v 0 || {
  cecho "错误: spacedust prefixid 失败"
  exit 1
}

cecho "提取聚类信息..."
awk '{ print $2"\t"$3 }' "${JOBNAME}_pref" > qid_tid
awk '{ print $1 }' "${JOBNAME}_pref" > cluid
rm "${JOBNAME}_pref"


cecho "转换序列名称..."
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

cecho "格式化序列名称..."
sed -i 's/NZ_/NZ./g' qname_tname
sed -i 's/NC_/NC./g' qname_tname
tr '_' '\t' < qname_tname > qname_tname_sep
rm tmp_qname qname_tname

cecho "处理序列集合信息..."
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

cecho "生成最终结果文件..."
paste cluid qset_tset qid_tid qname_tname_sep > "${JOBNAME}_plot"
rm qid_tid qname_tname_sep qset_tset cluid

cecho "生成输入序列前缀信息..."
spacedust prefixid ${DATABASE_DIR}/${JOBNAME} ${DATABASE_DIR}/${JOBNAME}_pref --tsv -v 0 || {
  cecho "错误: 生成输入序列前缀信息失败"
  exit 1
}

cecho "所有处理步骤完成！"

cecho "开始整理输出文件..."
mkdir -p ${OUTPUT_DIR}/{results,logs,database}

cecho "移动结果文件到输出目录..."
mv "${JOBNAME}_plot" ${OUTPUT_DIR}/results/
[ -f "${JOBNAME}_result" ] && mv "${JOBNAME}_result" ${OUTPUT_DIR}/results/

cecho "[复制数据库文件...]"
cp ${DATABASE_DIR}/${JOBNAME}.lookup ${OUTPUT_DIR}/database/ 2>/dev/null
cp ${DATABASE_DIR}/${JOBNAME}_pref ${OUTPUT_DIR}/database/ 2>/dev/null
cp ${DATABASE_DIR}/${JOBNAME}.source ${OUTPUT_DIR}/database/ 2>/dev/null


cecho "[清理中间文件...]"
mv "${ORIGIN_DIR}/tmp/" "${OUTPUT_DIR}/logs/"
rm -rf tmp/ ${DATABASE_DIR} ${PROCESSION_DIR}

rm -f ${JOBNAME}.* ${JOBNAME}_result_seq_to_clu.* ${JOBNAME}.index.*
rm -f qid_tid cluid tmp_qname qname_tname tmp_qset qset_tset qname_tname_sep 2>/dev/null

cecho ""
cecho "🎉 Spacedust 分析完成！"
cecho "最终输出目录: ${OUTPUT_DIR}/"
cecho "[主要结果文件: ${OUTPUT_DIR}/results/${JOBNAME}_plot]"
