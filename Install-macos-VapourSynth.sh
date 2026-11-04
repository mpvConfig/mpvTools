#!/bin/bash
set -e

echo "=== Installing mpv + VapourSynth + MVTools + open-svpflow (macOS) ==="

# ---------------- Language selection ----------------
echo ""
while true; do
    printf "Please enter the language/语言 (zh, zh-TW, en): "
    read -r LANG_CHOICE
    if [ -z "$LANG_CHOICE" ]; then
        LANG_CHOICE="en"
        break
    fi
    case "$(echo "$LANG_CHOICE" | tr '[:upper:]' '[:lower:]')" in
        zh)    LANG_CHOICE="zh";    break ;;
        zh-tw) LANG_CHOICE="zh-TW"; break ;;
        en)    LANG_CHOICE="en";    break ;;
        *)     echo "  [!!] Invalid choice: '$LANG_CHOICE'. Please enter zh, zh-TW or en." ;;
    esac
done

# ---------------- Localization data (only inputBlock) ----------------
case "$LANG_CHOICE" in
    zh)
        INPUT_BLOCK=$(cat << 'EOF'

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
)
        ;;
    zh-TW)
        INPUT_BLOCK=$(cat << 'EOF'

# ============ mpv MVTools 插幀 ============
Alt+0 vf clr "" #menu: 影片增強 > 插幀模式 > 關閉 VS 插幀
Alt+1 vf set vapoursynth="~~/vs/60fps-lq.vpy" #menu: 影片增強 > 插幀模式 > VS-MVTools LQ
Alt+2 vf set vapoursynth="~~/vs/60fps-mq.vpy" #menu: 影片增強 > 插幀模式 > VS-MVTools MQ
Alt+3 vf set vapoursynth="~~/vs/60fps-hq.vpy" #menu: 影片增強 > 插幀模式 > VS-MVTools HQ

# ============ mpv open-svpflow 插幀 ============
Alt+4 vf set vapoursynth="~~/vs/open-svpflow-lq.vpy" #menu: 影片增強 > 插幀模式 > VS-OPEN-SVP LQ
Alt+5 vf set vapoursynth="~~/vs/open-svpflow-mq.vpy" #menu: 影片增強 > 插幀模式 > VS-OPEN-SVP MQ
Alt+6 vf set vapoursynth="~~/vs/open-svpflow-hq.vpy" #menu: 影片增強 > 插幀模式 > VS-OPEN-SVP HQ
EOF
)
        ;;
    en|*)
        INPUT_BLOCK=$(cat << 'EOF'

# ============ mpv MVTools Interpolation ============
Alt+0 vf clr "" #menu: Video FX > Interpolation > Disable VapourSynth Interpolation
Alt+1 vf set vapoursynth="~~/vs/60fps-lq.vpy" #menu: Video FX > Interpolation > VS-MVTools LQ
Alt+2 vf set vapoursynth="~~/vs/60fps-mq.vpy" #menu: Video FX > Interpolation > VS-MVTools MQ
Alt+3 vf set vapoursynth="~~/vs/60fps-hq.vpy" #menu: Video FX > Interpolation > VS-MVTools HQ

# ============ mpv open-svpflow Interpolation ============
Alt+4 vf set vapoursynth="~~/vs/open-svpflow-lq.vpy" #menu: Video FX > Interpolation > VS-OPEN-SVP LQ
Alt+5 vf set vapoursynth="~~/vs/open-svpflow-mq.vpy" #menu: Video FX > Interpolation > VS-OPEN-SVP MQ
Alt+6 vf set vapoursynth="~~/vs/open-svpflow-hq.vpy" #menu: Video FX > Interpolation > VS-OPEN-SVP HQ
EOF
)
        ;;
esac

# 1. Check Homebrew
if ! command -v brew &> /dev/null; then
    echo "Homebrew not detected. Please install it first: https://brew.sh/"
    exit 1
fi

# 2. Install dependencies (MVTools via brew)
echo "Installing core dependencies (already-installed packages will be skipped)..."
brew install mpv vapoursynth vapoursynth-mvtools

# 3. Install open-svpflow (via pip)
# The brew-installed vapoursynth ships its own python environment; install open-svpflow into it
echo "Installing open-svpflow (open-source implementation of the SVP algorithm)..."
# Use python3's pip with --user to install into the user directory and avoid permission issues
python3 -m pip install --user --upgrade open-svpflow

# 4. Prepare directories
MPV_DIR="$HOME/.config/mpv"
VS_DIR="$MPV_DIR/vs"
mkdir -p "$VS_DIR"

# 5. Download .vpy interpolation scripts
echo "Downloading latest interpolation scripts from GitHub..."
BASE_URL="https://github.com/mpvConfig/mpvTools/raw/refs/heads/main/vs"

# MVTools scripts
curl -sL -o "$VS_DIR/60fps-lq.vpy" "$BASE_URL/60fps-lq.vpy"
curl -sL -o "$VS_DIR/60fps-mq.vpy" "$BASE_URL/60fps-mq.vpy"
curl -sL -o "$VS_DIR/60fps-hq.vpy" "$BASE_URL/60fps-hq.vpy"

# open-svpflow scripts
curl -sL -o "$VS_DIR/open-svpflow-lq.vpy" "$BASE_URL/open-svpflow-lq.vpy"
curl -sL -o "$VS_DIR/open-svpflow-mq.vpy" "$BASE_URL/open-svpflow-mq.vpy"
curl -sL -o "$VS_DIR/open-svpflow-hq.vpy" "$BASE_URL/open-svpflow-hq.vpy"

# 6. Configure hotkeys
INPUT_CONF="$MPV_DIR/input.conf"
if grep -q "open-svpflow-lq.vpy" "$INPUT_CONF" 2>/dev/null; then
    echo "Hotkeys already present, skipping configuration."
else
    echo "Adding hotkeys..."
    printf '%s\n' "$INPUT_BLOCK" >> "$INPUT_CONF"
fi

echo "=== Installation complete! Run 'mpv <video>' in a terminal to test ==="
echo "MVTools hotkeys: Alt+1(LQ) / Alt+2(MQ) / Alt+3(HQ)"
echo "open-svpflow hotkeys: Alt+4(LQ) / Alt+5(MQ) / Alt+6(HQ)"
echo "Enjoy! Press any key to close."