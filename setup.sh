#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
NC='\033[0m'

OS="$(uname)"
echo -e "${CYAN}=== NexusEnv Setup ===${NC}"
echo -e "检测平台: ${GREEN}${OS}${NC}"
echo ""

# ===== 1. 安装 SSHFS 依赖 =====
echo -e "${CYAN}[1/5] 检查 SSHFS 依赖${NC}"
if command -v sshfs &>/dev/null; then
    echo -e "  ${GREEN}sshfs 已安装${NC}"
else
    echo -e "  ${YELLOW}sshfs 未安装，正在安装...${NC}"
    if [[ "$OS" == "Darwin" ]]; then
        if ! command -v brew &>/dev/null; then
            echo -e "  ${RED}需要 Homebrew。请先安装: https://brew.sh${NC}"
            exit 1
        fi
        # macOS 需要 macFUSE + sshfs（通过第三方 tap）
        if ! brew list macfuse &>/dev/null 2>&1; then
            echo -e "  ${YELLOW}安装 macFUSE（可能需要系统权限和重启）...${NC}"
            brew install --cask macfuse
        fi
        # sshfs 官方 formula 不支持 macOS，使用 gromgit/fuse tap
        if ! brew tap | grep -q "gromgit/fuse" 2>/dev/null; then
            brew tap gromgit/fuse
        fi
        brew install gromgit/fuse/sshfs-mac
    else
        # Linux
        if command -v apt &>/dev/null; then
            sudo apt update && sudo apt install -y sshfs
        elif command -v yum &>/dev/null; then
            sudo yum install -y sshfs
        elif command -v dnf &>/dev/null; then
            sudo dnf install -y sshfs
        else
            echo -e "  ${RED}无法自动安装 sshfs，请手动安装${NC}"
            exit 1
        fi
    fi
    echo -e "  ${GREEN}sshfs 安装完成${NC}"
fi

# ===== 2. 配置 SSH ControlMaster =====
echo -e "${CYAN}[2/5] 配置 SSH ControlMaster${NC}"

# 创建 socket 目录
mkdir -p "$HOME/.ssh/sockets"
chmod 700 "$HOME/.ssh/sockets"
echo -e "  ${GREEN}~/.ssh/sockets/ 目录已就绪${NC}"

# 检查是否已有 ControlMaster 配置
if grep -q "ControlMaster" "$HOME/.ssh/config" 2>/dev/null; then
    echo -e "  ${YELLOW}~/.ssh/config 中已存在 ControlMaster 配置，跳过${NC}"
else
    echo "" >> "$HOME/.ssh/config"
    cat "$SCRIPT_DIR/config/ssh_controlmaster.conf" >> "$HOME/.ssh/config"
    echo -e "  ${GREEN}ControlMaster 配置已追加到 ~/.ssh/config${NC}"
fi

# ===== 3. 创建挂载点目录 + 初始化配置 =====
echo -e "${CYAN}[3/5] 创建挂载点目录${NC}"
mkdir -p "$HOME/mnt"
echo -e "  ${GREEN}~/mnt/ 目录已就绪${NC}"

# ===== 4. 生成配置文件 =====
echo -e "${CYAN}[4/5] 初始化配置${NC}"
NEXUS_CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/nexus"
NEXUS_CONFIG="$NEXUS_CONFIG_DIR/config"
if [[ -f "$NEXUS_CONFIG" ]]; then
    echo -e "  ${YELLOW}配置文件已存在: $NEXUS_CONFIG，跳过${NC}"
else
    echo -e "  ${YELLOW}将自动运行 nexus init 生成配置...${NC}"
    bash "$SCRIPT_DIR/nexus" init
fi

# ===== 5. 链接 nexus 到 PATH =====
echo -e "${CYAN}[5/5] 链接 nexus 到 PATH${NC}"
LOCAL_BIN="$HOME/.local/bin"
mkdir -p "$LOCAL_BIN"

NEXUS_PATH="$SCRIPT_DIR/nexus"
LINK_PATH="$LOCAL_BIN/nexus"

if [[ -L "$LINK_PATH" ]]; then
    rm "$LINK_PATH"
fi
ln -s "$NEXUS_PATH" "$LINK_PATH"
echo -e "  ${GREEN}nexus -> $LINK_PATH${NC}"

# 检查 PATH
if [[ ":$PATH:" != *":$LOCAL_BIN:"* ]]; then
    echo -e "  ${YELLOW}提示: $LOCAL_BIN 不在 PATH 中${NC}"
    echo -e "  ${YELLOW}请将以下内容添加到你的 shell 配置文件 (~/.zshrc 或 ~/.bashrc):${NC}"
    echo -e "  ${CYAN}export PATH=\"\$HOME/.local/bin:\$PATH\"${NC}"
fi

echo ""
echo -e "${GREEN}=== 安装完成 ===${NC}"
echo -e "开始使用:"
echo -e "  ${CYAN}nexus init${NC}            # 重新生成配置"
echo -e "  ${CYAN}nexus connect <host>${NC} # 连接服务器（2FA）"
echo -e "  ${CYAN}nexus ssh <host>${NC}     # SSH 到服务器"
echo -e "  ${CYAN}nexus mount <host>${NC}   # 挂载远程文件"
echo -e "  ${CYAN}nexus status${NC}         # 查看状态"
