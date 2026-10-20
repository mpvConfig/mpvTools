#!/bin/bash
set -e
echo "=== 开始安装 mpv + VapourSynth + MVTools + open-svpflow (Linux/Ubuntu) ==="

# 1. 安装系统级依赖 (只在这里提权)
echo "正在更新软件源并安装 mpv、pip3 (需要管理员权限)..."
sudo apt update
sudo apt install -y mpv python3-pip

# 2. 用户级安装 VapourSynth (不要 sudo！)
echo "正在安装 VapourSynth..."
pip3 install --user vapoursynth
pip3 install --user vapoursynth-mvtools

# 3. 安装 open-svpflow (通过 pip，与 VapourSynth 同一环境)
echo "正在安装 open-svpflow..."
pip3 install --user --upgrade open-svpflow

# 4. 准备目录 (普通用户权限)
MPV_DIR="$HOME/.config/mpv"
VS_DIR="$MPV_DIR/vs"
mkdir -p "$VS_DIR"

# 5. 下载 .vpy 脚本
echo "正在从 GitHub 下载最新插帧脚本..."
BASE_URL="https://github.com/mpvConfig/mpvTools/raw/refs/heads/main/vs"

# MVTools 脚本
curl -sL -o "$VS_DIR/60fps-lq.vpy" "$BASE_URL/60fps-lq.vpy"
curl -sL -o "$VS_DIR/60fps-mq.vpy" "$BASE_URL/60fps-mq.vpy"
curl -sL -o "$VS_DIR/60fps-hq.vpy" "$BASE_URL/60fps-hq.vpy"

# open-svpflow 脚本
curl -sL -o "$VS_DIR/open-svpflow-lq.vpy" "$BASE_URL/open-svpflow-lq.vpy"
curl -sL -o "$VS_DIR/open-svpflow-mq.vpy" "$BASE_URL/open-svpflow-mq.vpy"
curl -sL -o "$VS_DIR/open-svpflow-hq.vpy" "$BASE_URL/open-svpflow-hq.vpy"

# 6. 配置快捷键 (普通用户权限)
INPUT_CONF="$MPV_DIR/input.conf"
if grep -q "open-svpflow-lq.vpy" "$INPUT_CONF" 2>/dev/null; then
    echo "快捷键已存在，跳过配置。"
else
    echo "正在添加快捷键..."
    cat << 'EOF' >> "$INPUT_CONF"

# ============ mpv MVTools 插帧 ============
Alt+0 vf clr "" #menu: 视频增强 > 插帧模式 > 关闭 VS 插帧
Alt+1 vf set vapoursynth="~~/vs/60fps-lq.vpy" #menu: 视频增强 > 插帧模式 > VS-MVTools LQ
Alt+2 vf set vapoursynth="~~/vs/60fps-mq.vpy" #menu: 视频增强 > 插帧模式 > VS-MVTools MQ
Alt+3 vf set vapoursynth="~~/vs/60fps-hq.vpy" #menu: 视频增强 > 插帧模式 > VS-MVTools HQ

# ============ mpv open-svpflow 插帧 ============
Alt+4 vf set vapoursynth="~~/vs/open-svpflow-lq.vpy" #menu: 视频增强 > 插帧模式 > VS-OPEN-SVP LQ
Alt+5 vf set vapoursynth="~~/vs/open-svpflow-mq.vpy" #menu: 视频增强 > 插帧模式 > VS-OPEN-SVP MQ
Alt+6 vf set vapoursynth="~~/vs/open-svpflow-hq.vpy" #menu: 视频增强 > 插帧模式 > VS-OPEN-SVP HQ
EOF
fi

echo "=== 安装完成！请用终端输入 mpv 播放视频测试 ==="
echo "MVTools 快捷键: Alt+1(LQ) / Alt+2(MQ) / Alt+3(HQ)"
echo "open-svpflow 快捷键: Alt+4(LQ) / Alt+5(MQ) / Alt+6(HQ)"