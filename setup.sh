#!/bin/bash

# ==========================================
# Arch Linux WSL 自动化初始化脚本 (优化版)
# Author: Iris-Neko (Modified)
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

# ==========================================
# 0. 提前获取用户输入 (Early Input)

echo -e "${BLUE}>>> Pre-configuration: Setup User Credentials${NC}"

# --- 尝试 1: 从当前工作目录自动读取 ---
# 修改点：直接指向当前路径下的 wsl_cred.txt
CRED_FILE="$(pwd)/wsl_cred.txt"
AUTO_LOAD_SUCCESS=false


# 可选：打印一下当前在哪个目录找文件，方便调试
echo -e "${BLUE}Searching for credentials in: $CRED_FILE${NC}"

if [ -f "$CRED_FILE" ]; then
    echo -e "${BLUE}检测到自动配置文件，正在解析...${NC}"
    # 清洗 CRLF 换行符并读取第一行
    CRED_LINE=$(head -n 1 "$CRED_FILE" | tr -d '\r')
    
    # 解析变量
    FILE_USER=$(echo "$CRED_LINE" | cut -d':' -f1)
    FILE_PASS=$(echo "$CRED_LINE" | cut -d':' -f2)

    # 简单验证
    if [ ! -z "$FILE_USER" ] && [ ! -z "$FILE_PASS" ]; then
        NEW_USER="$FILE_USER"
        NEW_PASS="$FILE_PASS"
        echo -e "${GREEN}成功加载用户凭证: [ $NEW_USER ]${NC}"
        AUTO_LOAD_SUCCESS=true
        
        # 为了安全，读取后删除明文文件
        rm -f "$CRED_FILE"
    else
        echo -e "${RED}配置文件格式无效，转为手动输入模式。${NC}"
    fi
else
    # 增加一个提示，告诉用户没找到文件
    echo -e "${YELLOW}未在当前目录找到 wsl_cred.txt，将使用手动输入模式。${NC}"
fi

# --- 尝试 2: 交互式输入 (如果自动读取未成功) ---
if [ "$AUTO_LOAD_SUCCESS" = false ]; then
    echo "为了实现自动化安装，请先设置将要创建的用户名和密码。"
    
    while true; do
        read -p "请输入用户名 (Enter username): " NEW_USER
        if [[ -z "$NEW_USER" ]]; then
            echo -e "${RED}用户名不能为空，请重试。${NC}"
            continue
        fi
        
        if id "$NEW_USER" &>/dev/null; then
            echo -e "${RED}用户 $NEW_USER 已存在。脚本将跳过创建，但为了安全请确认你已知晓密码。${NC}"
            # 如果用户已存在，通常也需要设置 PASS 变量供后续逻辑使用(比如 sudo 提权验证)，或者直接 break
            break
        fi
        
        # 密码输入 (使用 -s 隐藏输入)
        read -s -p "请输入密码 (Enter password): " NEW_PASS
        echo ""
        read -s -p "请再次输入密码 (Confirm password): " NEW_PASS_CONFIRM
        echo ""

        if [ "$NEW_PASS" == "$NEW_PASS_CONFIRM" ] && [ ! -z "$NEW_PASS" ]; then
            break
        else
            echo -e "${RED}密码不匹配或为空，请重试。${NC}"
        fi
    done
fi

echo -e "${GREEN}>>> 凭据已记录。脚本将自动运行，您可以去喝杯咖啡了 ☕。${NC}"
sleep 2

# ==========================================
# 开始自动化流程
# ==========================================

# 2. 初始化 Pacman 并更新
echo -e "${GREEN}>>> Initializing Pacman keys & Updating system...${NC}"
pacman-key --init
pacman-key --populate archlinux
pacman -Syyu --noconfirm

# 3. 安装基础软件
echo -e "${GREEN}>>> Installing essentials (base-devel, git, zsh, nano, tmux, wget)...${NC}"
pacman -S --noconfirm base-devel git zsh nano tmux wget curl unzip openssh man-db man-pages net-tools fastfetch

export EDITOR=nano

# 4. 创建用户 (使用之前获取的变量)
echo -e "${BLUE}------------------------------------------------${NC}"
echo -e "${BLUE}Creating user $NEW_USER...${NC}"

if id "$NEW_USER" &>/dev/null; then
    echo -e "${BLUE}User $NEW_USER already exists. Skipping creation.${NC}"
else
    # 创建用户
    useradd -m -G wheel -s /bin/zsh "$NEW_USER"
    
    # 非交互式设置密码
    echo "$NEW_USER:$NEW_PASS" | chpasswd
    echo -e "${GREEN}>>> Password set for $NEW_USER successfully.${NC}"
    
    # 配置 Sudo (允许 wheel 组使用 sudo)
    if [ ! -f /etc/sudoers ]; then touch /etc/sudoers; fi
    sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers
    echo -e "${GREEN}>>> User $NEW_USER created and added to wheel group.${NC}"
fi

# 5. 配置 WSL 默认登录用户 AND 开启 Systemd
echo "配置 WSL 默认登录用户 AND 开启 Systemd"
echo -e "${GREEN}>>> Configuring WSL settings (Default User & Systemd)...${NC}"
WSL_CONF="/etc/wsl.conf"
if [ ! -f "$WSL_CONF" ]; then touch "$WSL_CONF"; fi

# --- 5a. 设置默认用户 ---
if grep -q "\[user\]" "$WSL_CONF"; then
    sed -i "s/default=.*/default=$NEW_USER/" "$WSL_CONF"
else
    echo -e "\n[user]\ndefault=$NEW_USER" >> "$WSL_CONF"
fi

# --- 5b. 开启 Systemd ---
# 检查是否已有 [boot] 字段
if grep -q "\[boot\]" "$WSL_CONF"; then
    # 如果有 systemd 配置，则强制改为 true
    if grep -q "systemd=" "$WSL_CONF"; then
        sed -i "s/systemd=.*/systemd=true/" "$WSL_CONF"
    else
        # 如果有 [boot] 但没有 systemd 行，在 [boot] 下面添加
        sed -i "/\[boot\]/a systemd=true" "$WSL_CONF"
    fi
else
    # 如果完全没有 [boot] 字段，直接追加
    echo -e "\n[boot]\nsystemd=true" >> "$WSL_CONF"
fi

echo -e "${GREEN}>>> WSL configuration updated (User: $NEW_USER, Systemd: Enabled).${NC}"

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
if ! grep -q "fastfetch" "$HOME/.zshrc"; then
  echo "" >> "$HOME/.zshrc"
  echo "# Start fastfetch on terminal launch" >> "$HOME/.zshrc"
  echo "fastfetch" >> "$HOME/.zshrc"
fi
'

# 9. Compile & Install Yay (AUR Helper)
YAY_INSTALL_SCRIPT='
if ! command -v yay &> /dev/null; then
  echo ">>> [User] Installing yay (AUR Helper)..."
  cd "$HOME"
  
  # 清理旧目录
  rm -rf tmp_yay_build
  mkdir -p tmp_yay_build && cd tmp_yay_build
  git clone https://aur.archlinux.org/yay.git
  cd yay
  
  # 使用传入的环境变量 NEW_PASS
  echo "pass=$NEW_PASS"
  echo "$NEW_PASS" | sudo -S -v
  
  # 开始构建
  makepkg -si --noconfirm
  
  cd "$HOME"
  rm -rf tmp_yay_build
fi
'

su - "$NEW_USER" -c "export NEW_PASS='$NEW_PASS'; $YAY_INSTALL_SCRIPT"
sleep 10
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
echo -e "${GREEN}🎉 Setup Complete! Please run the following in PowerShell:${NC}"
echo -e "${RED}wsl --shutdown${NC}"
echo -e "${BLUE}==============================================${NC}"