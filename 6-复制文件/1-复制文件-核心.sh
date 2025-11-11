#!/bin/bash

# 简化版所有项复制脚本
# 现在行为：复制 SOURCE_DIR 下的所有非隐藏项（文件或目录）到 TARGET_DIR（不扫盘）
# 使用cp命令，保留原有日志/进度/错误处理逻辑

# 日期: 2025年9月24日

# 设置变量
SOURCE_DIR="/mnt/chucunpan2/bacteria/" #* 需要被复制的源目录
TARGET_DIR="/data_raid/7_luolintao/2-NCBI-2024/" #* 目标目录
LOG_FILE="/data_raid/7_luolintao/copy_$(date +%Y%m%d_%H%M%S).log" #* 日志文件
PROGRESS_FILE="/data_raid/7_luolintao//copy_Assembly_progress.txt" #* 进度文件


# 函数：记录日志
log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# 函数：显示进度
show_progress() {
    local current=$1
    local total=$2
    local item_name=$3
    local progress_percent=0
    if [ "$total" -gt 0 ]; then
        progress_percent=$((current * 100 / total))
    fi
    echo "进度: [$current/$total] ($progress_percent%) - 正在处理: $item_name" | tee -a "$LOG_FILE" > "$PROGRESS_FILE"
}

# 函数：复制单个文件或目录（文件保留属性，目录递归复制）
copy_item() {
    local src="$1"
    local name
    name=$(basename "$src")
    local target_path="$TARGET_DIR/$name"

    log_message "开始复制: $name"
    log_message "源路径: $src"
    log_message "目标路径: $target_path"

    # 若目标已存在，跳过（可按需改为覆盖）
    if [ -e "$target_path" ]; then
        log_message "跳过: 目标已存在: $target_path"
        return 0
    fi

    if [ -d "$src" ]; then
        # 目录：递归复制
        log_message "目录复制开始（cp -r）..."
        if cp -a "$src" "$target_path" 2>&1 | tee -a "$LOG_FILE"; then
            log_message "成功复制目录: $name"
            return 0
        else
            log_message "错误: 复制目录 $name 失败"
            rm -rf "$target_path" 2>/dev/null
            return 1
        fi
    else
        # 普通文件：保留属性
        log_message "文件复制开始（cp -p）..."
        if cp -p "$src" "$target_path" 2>&1 | tee -a "$LOG_FILE"; then
            log_message "成功复制文件: $name"
            return 0
        else
            log_message "错误: 复制文件 $name 失败"
            rm -f "$target_path" 2>/dev/null
            return 1
        fi
    fi
}

# 主函数
main() {
    log_message "=========================================="
    log_message "开始执行：复制 $SOURCE_DIR 下所有非隐藏项（文件与目录）到 $TARGET_DIR"
    log_message "使用命令: cp (目录使用 cp -a, 文件使用 cp -p)"
    log_message "=========================================="

    # 检查源目录
    if [ ! -d "$SOURCE_DIR" ]; then
        log_message "错误: 源目录不存在: $SOURCE_DIR"
        exit 1
    fi

    # 确保目标目录存在
    mkdir -p "$TARGET_DIR"
    if [ ! -d "$TARGET_DIR" ]; then
        log_message "错误: 无法创建目标目录: $TARGET_DIR"
        exit 1
    fi

    # 获取源目录下所有非隐藏项（文件或目录）
    log_message "正在列出源目录下的所有非隐藏项..."
    items=()
    for item in "$SOURCE_DIR"/*; do
        # 当目录为空时，shell 会把字面字符串 "$SOURCE_DIR/*" 作为结果 -> 需要过滤
        if [ -e "$item" ]; then
            items+=("$item")
        fi
    done

    if [ ${#items[@]} -eq 0 ]; then
        log_message "警告: 在 $SOURCE_DIR 中未找到任何非隐藏项（可能为空或仅有隐藏文件）"
        exit 0
    fi

    log_message "找到 ${#items[@]} 个项（文件/目录），准备逐个复制："
    for it in "${items[@]}"; do
        log_message "  - $(basename "$it")"
    done

    # 初始化计数器
    local total_items=${#items[@]}
    local current_item=0
    local success_count=0
    local failed_count=0
    local start_time=$(date +%s)

    # 复制循环
    log_message "开始复制过程..."
    for it in "${items[@]}"; do
        current_item=$((current_item + 1))
        local item_name
        item_name=$(basename "$it")
        local item_start_time=$(date +%s)

        show_progress "$current_item" "$total_items" "$item_name"

        if copy_item "$it"; then
            success_count=$((success_count + 1))
            local item_end_time=$(date +%s)
            local item_duration=$((item_end_time - item_start_time))
            log_message "项 $item_name 复制耗时: ${item_duration} 秒"
        else
            failed_count=$((failed_count + 1))
        fi

        log_message "当前进度: 成功 $success_count, 失败 $failed_count, 剩余 $((total_items - current_item))"
        log_message "----------------------------------------"
    done

    # 最终报告
    local end_time=$(date +%s)
    local total_duration=$((end_time - start_time))

    log_message "=========================================="
    log_message "复制任务完成"
    log_message "总计项: $total_items"
    log_message "成功复制: $success_count"
    log_message "复制失败: $failed_count"
    log_message "总耗时: $((total_duration / 60)) 分钟 $((total_duration % 60)) 秒"
    if [ $total_items -gt 0 ]; then
        log_message "平均每项耗时: $((total_duration / total_items)) 秒"
    fi
    log_message "日志文件: $LOG_FILE"
    log_message "=========================================="

    # 清理进度文件
    rm -f "$PROGRESS_FILE"

    if [ "$failed_count" -eq 0 ]; then
        log_message "🎉 所有项复制成功！"
        exit 0
    else
        log_message "⚠️  部分项复制失败，请检查日志文件。"
        exit 1
    fi
}

# 优雅退出处理
cleanup() {
    log_message "收到中断信号，正在清理..."
    rm -f "$PROGRESS_FILE"
    log_message "清理完成，脚本退出"
    exit 130
}

trap cleanup INT TERM

# 执行主函数
main "$@"
