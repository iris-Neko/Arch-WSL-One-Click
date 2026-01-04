#!/bin/bash

# ==========================================
# Arch Linux WSL Bootstrap Script
# Purpose: Install Python and launch main setup
# ==========================================

# 颜色定义
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}=== Arch Linux WSL Bootstrap ===${NC}"

# 检查 Root 权限
if [ "$EUID" -ne 0 ]; then 
  echo -e "${RED}请使用 root 权限运行此脚本！${NC}"
  echo -e "${YELLOW}运行：sudo bash bootstrap.sh${NC}"
  exit 1
fi

# 获取脚本所在目录（用于定位 Python 脚本）
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PYTHON_SCRIPT="$SCRIPT_DIR/arch_wsl_setup.py"

echo -e "${GREEN}>>> 步骤 1/3: 初始化 Pacman...${NC}"
if [ ! -d "/etc/pacman.d/gnupg" ]; then
    pacman-key --init
    pacman-key --populate archlinux
fi

echo -e "${GREEN}>>> 步骤 2/3: 安装 Python...${NC}"
if ! command -v python3 &> /dev/null; then
    pacman -Sy --noconfirm python
    echo -e "${GREEN}Python 安装完成！${NC}"
else
    echo -e "${BLUE}Python 已安装，跳过...${NC}"
fi

echo -e "${GREEN}>>> 步骤 3/3: 启动 Python 安装程序...${NC}"
echo ""

# 检查 Python 脚本是否存在
if [ ! -f "$PYTHON_SCRIPT" ]; then
    echo -e "${RED}错误：找不到 arch_wsl_setup.py${NC}"
    echo -e "${YELLOW}请确保 arch_wsl_setup.py 与此脚本在同一目录${NC}"
    exit 1
fi

# 启动 Python 脚本
python3 "$PYTHON_SCRIPT"

echo -e "\n${BLUE}=== Bootstrap 完成 ===${NC}"

