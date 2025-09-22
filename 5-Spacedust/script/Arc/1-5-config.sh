# Spacedust 分析配置文件
# 此文件包含Spacedust分析的默认参数设置

# 基本设置
DEFAULT_JOBNAME="spacedust_analysis"
DEFAULT_INPUT_MODE="query-target"  # query-target 或 all-against-all
DEFAULT_TARGET_DB="KEGG_70"        # KEGG_70 或 self-uploaded
DEFAULT_SEARCH_MODE="MMseqs2"      # MMseqs2 或 Foldseek
DEFAULT_RUN_PRODIGAL=true          # true 或 false
DEFAULT_MAX_GENE_GAP=3
DEFAULT_NUM_ITERATIONS=1

# 路径设置（相对于脚本目录）
SPACEDUST_BIN="../download/spacedust/bin/spacedust"
PRODIGAL_BIN="../download/prodigal/bin/prodigal.linux"
FOLDSEEK_BIN="../download/foldseek/bin/foldseek"
DATABASE_DIR="../database"
EXAMPLE_DIR="../Example"

# 数据库设置
KEGG_DATABASE_NAME="keggclusterdb"

# 输出设置
DEFAULT_OUTPUT_SUBDIR="spacedust_output"
TEMP_DIR_NAME="tmp"
DATABASE_SUBDIR="database"

# 文件扩展名
INPUT_EXTENSION_FNA=".fna"
INPUT_EXTENSION_FAA=".faa"
OUTPUT_EXTENSION_PLOT="_plot"
OUTPUT_EXTENSION_PREF="_pref"
OUTPUT_EXTENSION_STATS="_statistics.txt"

# 日志设置
LOG_LEVEL="INFO"  # DEBUG, INFO, WARNING, ERROR
LOG_FORMAT="%(asctime)s - %(levelname)s - %(message)s"
LOG_DATE_FORMAT="%Y-%m-%d %H:%M:%S"

# Spacedust运行参数
SPACEDUST_VERBOSE_LEVEL=0  # 0=quiet, 1=normal, 2=verbose

# 文件检查设置
CHECK_FILE_SIZE=true
MIN_FILE_SIZE_BYTES=100

# 后处理设置
GENERATE_STATISTICS=true
CLEANUP_TEMP_FILES=true
SAVE_INTERMEDIATE_FILES=false

# 性能设置
MAX_CONCURRENT_JOBS=1
MEMORY_LIMIT_GB=8

# 错误处理
CONTINUE_ON_ERROR=false
RETRY_COUNT=3
RETRY_DELAY_SECONDS=5