#!/bin/bash
set -e
echo "=== 开始安装 mpv + VapourSynth + MVTools (Linux/Ubuntu) ==="

# 1. 安装系统级依赖 (只在这里提权)
echo "正在更新软件源并安装 mpv、pip3 (需要管理员权限)..."
sudo apt update
sudo apt install -y mpv python3-pip

# 2. 用户级安装 VapourSynth (不要 sudo！)
# 使用 --user 参数，确保安装在当前普通用户的家目录
echo "正在安装 VapourSynth..."
pip3 install --user vapoursynth
pip3 install --user vapoursynth-mvtools

# 3. 准备目录 (普通用户权限)
MPV_DIR="$HOME/.config/mpv"
VS_DIR="$MPV_DIR/vs"
mkdir -p "$VS_DIR"

# 4. 下载 .vpy 脚本
echo "正在从 GitHub 下载最新插帧脚本..."
BASE_URL="https://github.com/mpvConfig/mpvTools/raw/refs/heads/main/vs"
curl -sL -o "$VS_DIR/60fps-lq.vpy" "$BASE_URL/60fps-lq.vpy"
curl -sL -o "$VS_DIR/60fps-mq.vpy" "$BASE_URL/60fps-mq.vpy"
curl -sL -o "$VS_DIR/60fps-hq.vpy" "$BASE_URL/60fps-hq.vpy"

# 5. 配置快捷键 (普通用户权限)
INPUT_CONF="$MPV_DIR/input.conf"
if grep -q "60fps-lq.vpy" "$INPUT_CONF" 2>/dev/null; then
    echo "快捷键已存在，跳过配置。"
else
    echo "正在添加快捷键..."
    cat << 'EOF' >> "$INPUT_CONF"

# ============ mpv MVTools 插帧 ============
Alt+0 vf clr ""
Alt+1 vf set vapoursynth="~~/vs/60fps-lq.vpy"
Alt+2 vf set vapoursynth="~~/vs/60fps-mq.vpy"
Alt+3 vf set vapoursynth="~~/vs/60fps-hq.vpy"
EOF
fi

echo "=== 安装完成！请用终端输入 mpv 播放视频测试 ==="