#!/bin/bash
set -e

echo "=== Installing mpv + VapourSynth + MVTools + open-svpflow (macOS) ==="

# ---------------- Shared i18n URL ----------------
I18N_URL="https://github.com/mpvConfig/mpvTools/raw/refs/heads/main/static/vs-i18n.txt"

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

# ---------------- Built-in English fallback ----------------
FALLBACK_BLOCK=$(cat << 'EOF'
# ============ mpv MVTools Interpolation ============
Alt+0 vf clr "" #menu: Video FX > Interpolation > Disable VapourSynth
Alt+1 vf set vapoursynth="~~/vs/60fps-lq.vpy" #menu: Video FX > Interpolation > VS-MVTools LQ
Alt+2 vf set vapoursynth="~~/vs/60fps-mq.vpy" #menu: Video FX > Interpolation > VS-MVTools MQ
Alt+3 vf set vapoursynth="~~/vs/60fps-hq.vpy" #menu: Video FX > Interpolation > VS-MVTools HQ

# ============ mpv open-svpflow Interpolation ============
Alt+4 vf set vapoursynth="~~/vs/open-svpflow-lq.vpy" #menu: Video FX > Interpolation > VS-OPEN-SVP LQ
Alt+5 vf set vapoursynth="~~/vs/open-svpflow-mq.vpy" #menu: Video FX > Interpolation > VS-OPEN-SVP MQ
Alt+6 vf set vapoursynth="~~/vs/open-svpflow-hq.vpy" #menu: Video FX > Interpolation > VS-OPEN-SVP HQ
EOF
)

# ---------------- Extract a [lang] section from vs-i18n.txt ----------------
load_input_block() {
    # $1 = file path, $2 = language key
    awk -v lang="[$2]" '
        $0 == lang { inside=1; next }
        /^\[[^]]+\]$/ { inside=0 }
        inside { print }
    ' "$1" | awk 'BEGIN{blank=0} {lines[NR]=$0} END{
        # trim trailing blank lines
        last=NR
        while (last>0 && lines[last] ~ /^[[:space:]]*$/) last--
        for (i=1;i<=last;i++) print lines[i]
    }'
}

# ---------------- Download and load shared i18n ----------------
I18N_TMP="$(mktemp -t vs-i18n.XXXXXX.txt)"
cleanup_i18n() { rm -f "$I18N_TMP"; }
trap cleanup_i18n EXIT

if curl -fsSL -o "$I18N_TMP" "$I18N_URL" 2>/dev/null && [ -s "$I18N_TMP" ]; then
    INPUT_BLOCK="$(load_input_block "$I18N_TMP" "$LANG_CHOICE")"
    if [ -n "$INPUT_BLOCK" ]; then
        echo "Loaded localization data ($LANG_CHOICE)."
    else
        echo "  [!!] Language '$LANG_CHOICE' not found in localization data."
        echo "  [!!] Falling back to built-in English defaults."
        INPUT_BLOCK="$FALLBACK_BLOCK"
    fi
else
    echo "  [!!] Failed to download localization data from: $I18N_URL"
    echo "  [!!] Falling back to built-in English defaults."
    INPUT_BLOCK="$FALLBACK_BLOCK"
fi

# 1. Check Homebrew
if ! command -v brew &> /dev/null; then
    echo "Homebrew not detected. Please install it first: https://brew.sh/"
    exit 1
fi

# 2. Install dependencies (MVTools via brew)
echo "Installing core dependencies (already-installed packages will be skipped)..."
brew install mpv vapoursynth vapoursynth-mvtools

# 3. Install open-svpflow (via pip)
echo "Installing open-svpflow (open-source implementation of the SVP algorithm)..."
python3 -m pip install --user --upgrade open-svpflow

# 4. Prepare directories
MPV_DIR="$HOME/.config/mpv"
VS_DIR="$MPV_DIR/vs"
mkdir -p "$VS_DIR"

# 5. Download .vpy interpolation scripts
echo "Downloading latest interpolation scripts from GitHub..."
BASE_URL="https://github.com/mpvConfig/mpvTools/raw/refs/heads/main/vs"

curl -sL -o "$VS_DIR/60fps-lq.vpy" "$BASE_URL/60fps-lq.vpy"
curl -sL -o "$VS_DIR/60fps-mq.vpy" "$BASE_URL/60fps-mq.vpy"
curl -sL -o "$VS_DIR/60fps-hq.vpy" "$BASE_URL/60fps-hq.vpy"

curl -sL -o "$VS_DIR/open-svpflow-lq.vpy" "$BASE_URL/open-svpflow-lq.vpy"
curl -sL -o "$VS_DIR/open-svpflow-mq.vpy" "$BASE_URL/open-svpflow-mq.vpy"
curl -sL -o "$VS_DIR/open-svpflow-hq.vpy" "$BASE_URL/open-svpflow-hq.vpy"

# 6. Configure hotkeys
INPUT_CONF="$MPV_DIR/input.conf"
if grep -q "open-svpflow-lq.vpy" "$INPUT_CONF" 2>/dev/null; then
    echo "Hotkeys already present, skipping configuration."
else
    echo "Adding hotkeys..."
    printf '\n%s\n' "$INPUT_BLOCK" >> "$INPUT_CONF"
fi

echo "=== Installation complete! Run 'mpv <video>' in a terminal to test ==="
echo "MVTools hotkeys: Alt+1(LQ) / Alt+2(MQ) / Alt+3(HQ)"
echo "open-svpflow hotkeys: Alt+4(LQ) / Alt+5(MQ) / Alt+6(HQ)"
echo "Enjoy! Press any key to close."