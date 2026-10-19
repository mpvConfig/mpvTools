#!/bin/bash
set -e

echo "=== 开始安装 mpv + VapourSynth + MVTools (macOS) ==="

# 1. 检查 Homebrew
if ! command -v brew &> /dev/null; then
    echo "未检测到 Homebrew，请先安装: https://brew.sh/"
    exit 1
fi

# 2. 安装依赖
echo "正在安装核心依赖 (如果已安装会自动跳过)..."
brew install mpv vapoursynth vapoursynth-mvtools

# 3. 准备目录
MPV_DIR="$HOME/.config/mpv"
VS_DIR="$MPV_DIR/vs"
mkdir -p "$VS_DIR"

# 4. 智能获取 .vpy 脚本
# 检查当前目录下是否有 .vpy 文件（如果用户是通过下载整个仓库解压的）

echo "正在从 GitHub 下载最新插帧脚本..."
BASE_URL="https://github.com/mpvConfig/mpvTools/raw/refs/heads/main/vs"
curl -sL -o "$VS_DIR/60fps-lq.vpy" "$BASE_URL/60fps-lq.vpy"
curl -sL -o "$VS_DIR/60fps-mq.vpy" "$BASE_URL/60fps-mq.vpy"
curl -sL -o "$VS_DIR/60fps-hq.vpy" "$BASE_URL/60fps-hq.vpy"

# 5. 配置快捷键
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