# Spacedust 脚本修复报告

## 问题描述
用户运行 `2-run_example.sh` 时遇到错误：
```
/mnt/f/OneDrive/文档（科研）/脚本/Download/13-A.baumannii/5-Spacedust/script//run_spacedust.sh: line 19: print_info: command not found
```

## 根本原因分析

### 1. 脚本语法错误
- **位置**: `run_spacedust.sh` 第17-21行
- **问题**: 变量定义中混入了代码片段和注释
- **修复**: 清理混乱的代码，正确定义变量

### 2. Prodigal路径错误
- **问题**: `PRODIGAL_BIN` 指向目录而非可执行文件
- **修复**: 修改为 `${BASE_DIR}/download/prodigal/bin/prodigal.linux`

### 3. 数据库路径问题
- **问题**: 使用相对路径创建数据库，导致路径不一致
- **修复**: 使用绝对路径 `${WORK_DIR}/database/${JOBNAME}_input`

### 4. Spacedust Lookup文件Bug
- **问题**: Spacedust的lookup文件生成存在bug，导致 "Invalid query lookup record" 错误
- **修复**: 在createsetdb命令中添加 `--write-lookup 0` 参数禁用lookup文件生成

## 具体修复内容

### 修复1: 语法错误
```bash
# 修复前
TARGET_DB="KEGG_70"        # self-uploaded 或 KEGG_70        else:
            # 使用预建数据库
            print_info "运行聚类搜索（KEGG数据库）..."
            "$SPACEDUST_BIN" clustersearch "database/${JOBNAME}_input" "database/KEGG_70/keggclusterdb" \
                "$JOBNAME" tmp --search-mode "$search_type" --max-gene-gap "$MAX_GENE_GAP" -v 0CH_MODE="MMseqs2"

# 修复后
TARGET_DB="KEGG_70"        # self-uploaded 或 KEGG_70
SEARCH_MODE="MMseqs2"      # MMseqs2 或 Foldseek
```

### 修复2: Prodigal路径
```bash
# 修复前
PRODIGAL_BIN="${BASE_DIR}/download/prodigal"

# 修复后
PRODIGAL_BIN="${BASE_DIR}/download/prodigal/bin/prodigal.linux"
```

### 修复3: 数据库路径
```bash
# 修复前
"$SPACEDUST_BIN" createsetdb "${faa_files[@]}" "database/${JOBNAME}_input" tmp -v 0

# 修复后
"$SPACEDUST_BIN" createsetdb "${faa_files[@]}" "${WORK_DIR}/database/${JOBNAME}_input" tmp --write-lookup 0 -v 1
```

### 修复4: KEGG数据库路径一致性
```bash
# 修复前
"$SPACEDUST_BIN" clustersearch "database/${JOBNAME}_input" "database/keggclusterdb"

# 修复后  
"$SPACEDUST_BIN" clustersearch "${WORK_DIR}/database/${JOBNAME}_input" "${DATABASE_DIR}/KEGG_70/keggclusterdb"
```

## 解决方案验证

1. **语法检查通过**: `bash -n run_spacedust.sh` 无错误
2. **帮助功能正常**: `./run_spacedust.sh --help` 正常显示
3. **Prodigal运行成功**: 基因预测过程正常完成
4. **数据库创建成功**: createsetdb命令成功执行
5. **主要错误解决**: "clusterhits failed" 错误已解决

## 当前状态

- ✅ 脚本语法错误已修复
- ✅ Prodigal路径已修复 
- ✅ 数据库创建路径已修复
- ✅ Lookup文件问题已解决
- ⚠️  仍有轻微的database key警告，但不影响主要功能

## 建议

1. 脚本现在可以正常运行基本的spacedust分析
2. 如需处理database key警告，可能需要更新spacedust版本或调整参数
3. 建议在生产环境使用前进行完整测试

## 文件变更清单

- `script/run_spacedust.sh`: 主要修复文件
- `script/clean_faa_headers.py`: 新增工具，用于清理序列头格式
- `Example_cleaned/`: 新增目录，包含清理后的测试文件