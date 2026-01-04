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

echo -e "${GREEN}>>> 步骤 2/4: 安装 Python...${NC}"
if ! command -v python3 &> /dev/null; then
    pacman -Sy --noconfirm python
    echo -e "${GREEN}Python 安装完成！${NC}"
else
    echo -e "${BLUE}Python 已安装，跳过...${NC}"
fi

echo -e "${GREEN}>>> 步骤 3/4: 安装 PyYAML (配置文件支持)...${NC}"
if ! python3 -c "import yaml" &> /dev/null; then
    pacman -S --noconfirm python-yaml
    echo -e "${GREEN}PyYAML 安装完成！${NC}"
else
    echo -e "${BLUE}PyYAML 已安装，跳过...${NC}"
fi

echo -e "${GREEN}>>> 步骤 4/5: 检查配置文件...${NC}"
CONFIG_FILE="$SCRIPT_DIR/setup.yaml"
if [ ! -f "$CONFIG_FILE" ]; then
    echo -e "${YELLOW}配置文件不存在，正在生成...${NC}"
    
    # 检查是否有中国配置模板
    if [ -f "$SCRIPT_DIR/setup-china.yaml" ]; then
        echo -e "${BLUE}检测到中国优化配置，是否使用？(y/n) [推荐]${NC}"
        read -p "选择: " choice
        if [ "$choice" = "y" ] || [ "$choice" = "Y" ] || [ -z "$choice" ]; then
            cp "$SCRIPT_DIR/setup-china.yaml" "$CONFIG_FILE"
            echo -e "${GREEN}✓ 已使用中国优化配置${NC}"
        else
            cp "$SCRIPT_DIR/setup.yaml.example" "$CONFIG_FILE"
            echo -e "${GREEN}✓ 已使用通用配置${NC}"
        fi
    else
        cp "$SCRIPT_DIR/setup.yaml.example" "$CONFIG_FILE"
        echo -e "${GREEN}✓ 已生成配置文件${NC}"
    fi
    
    echo -e "${YELLOW}提示: 可以编辑 setup.yaml 自定义配置${NC}"
    echo ""
fi

echo -e "${GREEN}>>> 步骤 5/5: 启动 Python 安装程序...${NC}"
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

