#!/bin/bash

# 定义颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 检查是否以 root 运行
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}Error: This script must be run as root.${NC}"
   exit 1
fi

echo -e "${BLUE}------------------------------------------------${NC}"
echo -e "${BLUE}       INTERACTIVE USER CREATION WIZARD         ${NC}"
echo -e "${BLUE}------------------------------------------------${NC}"

# 1. 获取用户名
while true; do
    read -p "Enter new username: " NEW_USER
    if [[ -z "$NEW_USER" ]]; then
        echo -e "${RED}Username cannot be empty.${NC}"
    elif id "$NEW_USER" &>/dev/null; then
        echo -e "${YELLOW}User '$NEW_USER' already exists. Please choose another name.${NC}"
    else
        break
    fi
done

# 2. 获取并确认密码
while true; do
    echo -n "Enter password for $NEW_USER: "
    read -s NEW_PASS
    echo
    echo -n "Confirm password: "
    read -s NEW_PASS_CONFIRM
    echo

    if [[ -z "$NEW_PASS" ]]; then
        echo -e "${RED}Password cannot be empty.${NC}"
    elif [[ "$NEW_PASS" != "$NEW_PASS_CONFIRM" ]]; then
        echo -e "${RED}Passwords do not match. Please try again.${NC}"
    else
        break
    fi
done

# 3. 选择 Shell
echo -e "\nChoose a default shell:"
echo "1) /bin/bash (Default)"
echo "2) /bin/zsh"
echo "3) /bin/fish"
read -p "Select [1-3]: " SHELL_CHOICE

case $SHELL_CHOICE in
    2)
        TARGET_SHELL="/bin/zsh"
        # 检查 zsh 是否安装
        if ! command -v zsh &> /dev/null; then
            echo -e "${YELLOW}Zsh not found. Installing zsh...${NC}"
            pacman -Sy --noconfirm zsh
        fi
        ;;
    3)
        TARGET_SHELL="/bin/fish"
        # 检查 fish 是否安装
        if ! command -v fish &> /dev/null; then
            echo -e "${YELLOW}Fish not found. Installing fish...${NC}"
            pacman -Sy --noconfirm fish
        fi
        ;;
    *)
        TARGET_SHELL="/bin/bash"
        ;;
esac

# 4. 创建用户 (核心逻辑)
echo -e "${BLUE}------------------------------------------------${NC}"
echo -e "${BLUE}Creating user $NEW_USER with shell $TARGET_SHELL...${NC}"

# 创建用户并添加到 wheel 组
useradd -m -G wheel -s "$TARGET_SHELL" "$NEW_USER"

if [[ $? -eq 0 ]]; then
    # 设置密码
    echo "$NEW_USER:$NEW_PASS" | chpasswd
    if [[ $? -eq 0 ]]; then
         echo -e "${GREEN}>>> User $NEW_USER created and password set.${NC}"
    else
         echo -e "${RED}>>> Failed to set password for $NEW_USER.${NC}"
         exit 1
    fi

    # 配置 Sudo
    echo -e "${BLUE}Configuring sudo privileges...${NC}"
    
    # 确保 sudo 已安装
    if ! command -v sudo &> /dev/null; then
        echo -e "${YELLOW}Sudo not found. Installing sudo...${NC}"
        pacman -Sy --noconfirm sudo
    fi

    if [ ! -f /etc/sudoers ]; then 
        echo -e "${YELLOW}/etc/sudoers not found, creating...${NC}"
        touch /etc/sudoers
    fi

    # 备份 sudoers 文件
    cp /etc/sudoers /etc/sudoers.bak

    # 启用 wheel 组 sudo 权限
    # 方法 A: 使用 sed 替换 (如果文件中存在被注释的行)
    if grep -q "# %wheel ALL=(ALL:ALL) ALL" /etc/sudoers; then
        sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers
        echo -e "${GREEN}>>> Uncommented wheel group in /etc/sudoers.${NC}"
    # 方法 B: 如果 grep 没找到，检查是否已经启用，如果没有启用则追加
    elif grep -q "^%wheel ALL=(ALL:ALL) ALL" /etc/sudoers; then
        echo -e "${GREEN}>>> Wheel group already enabled.${NC}"
    else
        # 安全追加到末尾
        echo "%wheel ALL=(ALL:ALL) ALL" >> /etc/sudoers
        echo -e "${GREEN}>>> Added wheel group to /etc/sudoers.${NC}"
    fi

else
    echo -e "${RED}>>> Failed to create user $NEW_USER.${NC}"
    exit 1
fi

echo -e "${BLUE}------------------------------------------------${NC}"
echo -e "${GREEN}SUCCESS: User setup complete!${NC}"