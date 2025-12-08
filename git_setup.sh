#!/bin/bash

# --- 颜色定义 ---
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${BLUE}=========================================${NC}"
echo -e "${BLUE}   GitHub 一键配置助手 (v5.1 超详细版)    ${NC}"
echo -e "${BLUE}=========================================${NC}"

# --- 1. 安装 ---
if ! command -v gh &> /dev/null; then
    echo -e "正在安装 GitHub 工具..."
    sudo pacman -S --noconfirm github-cli git > /dev/null
fi

# --- 2. 交互式教学 ---
echo -e "${YELLOW}>>> 马上开始配置，请严格按照下面 5 步操作：${NC}"
echo -e "------------------------------------------------------"
echo -e "Step 1: 看到 Protocol 时 -> 按 ${GREEN}⬇️ 下键${NC} 选中 SSH -> 回车"
echo -e "Step 2: 看到 Generate new SSH key 时 -> 直接 ${GREEN}回车${NC} (选 Yes)"
echo -e "Step 3: 看到 Enter a passphrase 时   -> 直接 ${GREEN}回车${NC} (不要设密码)"
echo -e "Step 4: 看到 Title for your key 时   -> 直接 ${GREEN}回车${NC}"
echo -e "Step 5: 看到 How to authenticate 时  -> 选 ${GREEN}Web browser${NC} -> 回车"
echo -e "------------------------------------------------------"
echo -e "${RED}⚠️  注意：最后它会给你一串验证码 (如 1234-5678)${NC}"
echo -e "   你需要复制那个码 -> 按回车打开浏览器 -> 粘贴码 -> 点击授权。"
echo -e "------------------------------------------------------"
echo -e "准备好了吗？按任意键开始..."
read -n 1 -s

# --- 3. 执行 ---
gh auth login

# --- 4. 结果验证 ---
echo -e "\n${YELLOW}>>> 正在验证连接...${NC}"
# 自动同步名字邮箱，防止 git log 里的名字是空的
gh_name=$(gh api user -q .name)
gh_email=$(gh api user -q .email)
[ -z "$gh_name" ] && gh_name=$(gh api user -q .login)
if [ -n "$gh_name" ]; then
    git config --global user.name "$gh_name"
    git config --global user.email "$gh_email"
fi

ssh -T git@github.com 2>&1 | grep "successfully" > /dev/null
if [ $? -eq 0 ]; then
    echo -e "${GREEN}🎉🎉🎉 全部搞定！你现在可以去写代码了！${NC}"
else
    echo -e "${RED}似乎没成功，请重新运行脚本再试一次。${NC}"
fi