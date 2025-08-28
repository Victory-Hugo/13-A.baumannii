#!/bin/bash

# 快速创建传输包脚本
# 用于在主打包完成后，快速创建便于传输的最终包

echo "🚀 EToKi环境快速打包工具"
echo "================================"
echo "开始时间: $(date)"

# 检查是否存在临时打包目录
TEMP_DIRS=$(ls -d /tmp/etoki_complete_* 2>/dev/null | head -1)

if [ -z "$TEMP_DIRS" ]; then
    echo "❌ 错误: 未找到临时打包目录"
    echo "请先运行主打包脚本: 1-环境打包.sh"
    exit 1
fi

PACKAGE_DIR="$TEMP_DIRS"
PACKAGE_NAME=$(basename "$PACKAGE_DIR")

echo "📁 找到打包目录: $PACKAGE_DIR"

# 检查打包目录内容
echo ""
echo "📋 检查打包内容:"
cd "$PACKAGE_DIR"
ls -lh

echo ""
echo "📊 当前目录大小:"
du -sh .

# 创建MD5校验文件
echo ""
echo "🔐 生成文件校验和..."
md5sum * > checksums.md5
echo "✓ 校验和文件已生成: checksums.md5"

# 创建快速验证脚本
echo ""
echo "📝 创建验证脚本..."
cat > verify_package.sh << 'EOF'
#!/bin/bash
echo "🔍 验证EToKi包完整性..."
echo "时间: $(date)"
echo ""

# 检查必要文件
REQUIRED_FILES=(
    "etoki_environment.yml"
    "etoki_env_binaries.tar.gz"
    "kraken_database.tar.gz"
    "install_etoki.sh"
    "README_安装使用指南.md"
    "checksums.md5"
)

echo "检查必要文件:"
for file in "${REQUIRED_FILES[@]}"; do
    if [ -f "$file" ]; then
        echo "✓ $file"
    else
        echo "✗ $file (缺失)"
    fi
done

echo ""
echo "验证文件校验和:"
if md5sum -c checksums.md5 >/dev/null 2>&1; then
    echo "✓ 所有文件校验和正确"
else
    echo "⚠️ 文件校验和验证失败，请重新下载"
    md5sum -c checksums.md5
fi

echo ""
echo "包大小统计:"
du -sh .
echo ""
echo "验证完成!"
EOF

chmod +x verify_package.sh
echo "✓ 验证脚本已创建: verify_package.sh"

# 创建最终压缩包
echo ""
echo "📦 创建最终传输包..."
cd /tmp

# 使用最高压缩率创建包
echo "正在压缩... (这可能需要几分钟)"
tar -czf "${PACKAGE_NAME}_final.tar.gz" "$PACKAGE_NAME/"

if [ $? -eq 0 ]; then
    echo "✅ 成功创建最终包: /tmp/${PACKAGE_NAME}_final.tar.gz"
else
    echo "❌ 压缩过程中出现错误"
    exit 1
fi

# 显示最终结果
echo ""
echo "📊 最终包信息:"
ls -lh "/tmp/${PACKAGE_NAME}_final.tar.gz"

FINAL_SIZE=$(ls -lh "/tmp/${PACKAGE_NAME}_final.tar.gz" | awk '{print $5}')
echo ""
echo "🎉 打包完成!"
echo "================================"
echo "📄 最终文件: /tmp/${PACKAGE_NAME}_final.tar.gz"
echo "📏 文件大小: $FINAL_SIZE"
echo "📁 包含内容: 完整EToKi环境 + 数据库 + 安装脚本 + 文档"
echo ""
echo "🚀 传输和使用步骤:"
echo "1. 将文件传输到目标服务器"
echo "2. 解压: tar -xzf ${PACKAGE_NAME}_final.tar.gz"
echo "3. 进入目录: cd $PACKAGE_NAME/"
echo "4. 验证包: ./verify_package.sh"
echo "5. 安装: ./install_etoki.sh"
echo ""
echo "📚 相关文档:"
echo "- 小白用户指南: 小白用户部署指南.md"
echo "- 详细安装说明: README_安装使用指南.md"
echo "- 技术文档: 管理员技术文档.md"
echo ""

# 创建传输命令提示
echo "💡 常用传输命令:"
echo "SCP传输: scp /tmp/${PACKAGE_NAME}_final.tar.gz user@server:/path/"
echo "rsync传输: rsync -avP /tmp/${PACKAGE_NAME}_final.tar.gz user@server:/path/"
echo ""

# 生成部署命令清单
cat > /tmp/deployment_commands.txt << EOF
# EToKi部署命令清单
# 生成时间: $(date)

# 1. 传输文件到服务器
scp /tmp/${PACKAGE_NAME}_final.tar.gz user@server:/home/user/

# 2. 在服务器上解压
ssh user@server "cd /home/user && tar -xzf ${PACKAGE_NAME}_final.tar.gz"

# 3. 验证包完整性
ssh user@server "cd /home/user/$PACKAGE_NAME && ./verify_package.sh"

# 4. 运行安装
ssh user@server "cd /home/user/$PACKAGE_NAME && ./install_etoki.sh"

# 5. 验证安装结果
ssh user@server "conda activate etoki && EToKi.py configure"
EOF

echo "📋 部署命令清单已保存到: /tmp/deployment_commands.txt"
echo ""
echo "✨ 全部完成! 您的EToKi环境已准备好部署到其他服务器!"
