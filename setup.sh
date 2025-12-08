#!/bin/bash

# ==========================================
# Arch Linux WSL 自动化初始化脚本
# Author: Iris-Neko
# GitHub: https://github.com/iris-Neko
# ==========================================

# 颜色定义
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}=== Arch Linux WSL Initialization Script ===${NC}"

# 1. 检查 Root 权限
if [ "$EUID" -ne 0 ]; then 
  echo -e "${RED}Please run as root!${NC}"
  exit 1
fi

# 2. 初始化 Pacman 并更新
echo -e "${GREEN}>>> Initializing Pacman keys & Updating system...${NC}"
pacman-key --init
pacman-key --populate archlinux
pacman -Syyu --noconfirm

# 3. 安装基础软件 (Nano, Tmux, Git, Base-devel)
echo -e "${GREEN}>>> Installing essentials (base-devel, git, zsh, nano, tmux, wget)...${NC}"
pacman -S --noconfirm base-devel git zsh nano tmux wget curl unzip openssh man-db man-pages net-tools

export EDITOR=nano

# 4. 创建用户
echo -e "${BLUE}------------------------------------------------${NC}"
echo -e "${BLUE}Creating a non-root user for daily use.${NC}"
read -p "Enter username: " NEW_USER

if id "$NEW_USER" &>/dev/null; then
    echo -e "${RED}User $NEW_USER exists. Skipping creation.${NC}"
else
    useradd -m -G wheel -s /bin/zsh "$NEW_USER"
    echo -e "${GREEN}>>> Set password for $NEW_USER:${NC}"
    passwd "$NEW_USER"
    
    # 配置 Sudo
    if [ ! -f /etc/sudoers ]; then touch /etc/sudoers; fi
    sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers
    echo -e "${GREEN}>>> User $NEW_USER created and added to wheel group.${NC}"
fi

# 5. 配置 WSL 默认登录用户
echo -e "${GREEN}>>> Setting WSL default user to $NEW_USER...${NC}"
if [ ! -f /etc/wsl.conf ]; then touch /etc/wsl.conf; fi
if grep -q "\[user\]" /etc/wsl.conf; then
    sed -i "s/default=.*/default=$NEW_USER/" /etc/wsl.conf
else
    echo -e "\n[user]\ndefault=$NEW_USER" >> /etc/wsl.conf
fi

# ==========================================
# Switch to User context for AUR & Dotfiles
# ==========================================

echo -e "${BLUE}>>> Switching to $NEW_USER for environment setup...${NC}"

# 6. Oh My Zsh
su - "$NEW_USER" -c '
if [ ! -d "$HOME/.oh-my-zsh" ]; then
    echo ">>> [User] Installing Oh My Zsh..."
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
fi
'

# 7. Zsh Plugins
su - "$NEW_USER" -c '
ZSH_CUSTOM="$HOME/.oh-my-zsh/custom"
if [ ! -d "$ZSH_CUSTOM/plugins/zsh-autosuggestions" ]; then
    echo ">>> [User] Installing zsh-autosuggestions..."
    git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM}/plugins/zsh-autosuggestions
fi
if [ ! -d "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" ]; then
    echo ">>> [User] Installing zsh-syntax-highlighting..."
    git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM}/plugins/zsh-syntax-highlighting
fi
'

# 8. Configure .zshrc
su - "$NEW_USER" -c '
echo ">>> [User] Configuring .zshrc..."
sed -i "s/^plugins=(git)/plugins=(z git zsh-autosuggestions zsh-syntax-highlighting)/" "$HOME/.zshrc"
if ! grep -q "export EDITOR=" "$HOME/.zshrc"; then
    echo "" >> "$HOME/.zshrc"
    echo "export EDITOR=nano" >> "$HOME/.zshrc"
fi
'

# 9. Compile & Install Yay (AUR Helper)
su - "$NEW_USER" -c '
if ! command -v yay &> /dev/null; then
    echo ">>> [User] Installing yay (AUR Helper)..."
    cd "$HOME"
    mkdir -p tmp_yay_build && cd tmp_yay_build
    git clone https://aur.archlinux.org/yay.git
    cd yay
    makepkg -si --noconfirm
    cd "$HOME"
    rm -rf tmp_yay_build
fi
'

# 10. Install Miniconda
su - "$NEW_USER" -c '
if [ ! -d "$HOME/miniconda3" ]; then
    echo ">>> [User] Installing Miniconda..."
    wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O ~/miniconda.sh
    bash ~/miniconda.sh -b -p "$HOME/miniconda3"
    rm ~/miniconda.sh
    "$HOME/miniconda3/bin/conda" init zsh
    "$HOME/miniconda3/bin/conda" config --set auto_activate_base false
fi
'

echo -e "${BLUE}==============================================${NC}"
echo -e "${GREEN}🎉 Setup Complete! Please run: wsl --shutdown${NC}"
echo -e "${BLUE}==============================================${NC}"