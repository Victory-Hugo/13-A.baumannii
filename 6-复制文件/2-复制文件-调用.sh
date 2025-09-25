#!/bin/bash

# 启动脚本 - 使用nohup确保SSH断开连接后仍能继续运行

# 日期: 2025年9月9日

SCRIPT_DIR="/data_ssd3/7_luolintao_Baoman/1-Assemble/"
SCRIPT_NAME="copy_baoman_nc_simple.sh"
SCRIPT_PATH="$SCRIPT_DIR/$SCRIPT_NAME"
NOHUP_LOG="$SCRIPT_DIR/nohup_Assemble_$(date +%Y%m%d_%H%M%S).log"

echo "=========================================="
echo "鲍曼NC文件夹复制任务启动器（简化版）"
echo "=========================================="
echo "脚本路径: $SCRIPT_PATH"
echo "nohup日志: $NOHUP_LOG"
echo "当前时间: $(date)"
echo "=========================================="

# 检查主脚本是否存在
if [ ! -f "$SCRIPT_PATH" ]; then
    echo "错误: 主脚本不存在: $SCRIPT_PATH"
    exit 1
fi

# 给主脚本添加执行权限
chmod +x "$SCRIPT_PATH"

echo "正在启动复制任务..."
echo "使用nohup确保SSH断开连接后仍能继续运行"
echo "可以使用以下命令查看进度:"
echo "  tail -f $SCRIPT_DIR/copy_progress.txt"
echo "  tail -f $SCRIPT_DIR/copy_baoman_nc_*.log"
echo "=========================================="

# 使用nohup启动任务
nohup "$SCRIPT_PATH" > "$NOHUP_LOG" 2>&1 &

# 获取进程ID
PID=$!
echo "任务已启动，进程ID: $PID"
echo "nohup日志文件: $NOHUP_LOG"

# 创建进程ID文件，方便后续管理
echo "$PID" > "$SCRIPT_DIR/copy_task.pid"
echo "进程ID已保存到: $SCRIPT_DIR/copy_task.pid"

echo "=========================================="
echo "任务启动完成！"
echo ""
echo "常用命令:"
echo "1. 查看实时进度:"
echo "   tail -f $SCRIPT_DIR/copy_progress.txt"
echo ""
echo "2. 查看详细日志:"
echo "   tail -f $NOHUP_LOG"
echo ""
echo "3. 检查任务是否在运行:"
echo "   ps -p $PID"
echo ""
echo "4. 停止任务 (如果需要):"
echo "   kill $PID"
echo ""
echo "5. 强制停止任务 (如果需要):"
echo "   kill -9 $PID"
echo "=========================================="
