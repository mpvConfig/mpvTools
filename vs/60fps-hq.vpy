# mpv MVTools 插帧 - 高画质(HQ) - 质量优先，非常吃 CPU 预设
# 可用文本编辑器按需修改参数
import os
import vapoursynth as vs

core = vs.core

# ====== 可按需修改 ======
DST_FPS = 60      # 目标帧率（显示器为 120Hz 可改为 120）
THREADS = 8
# ========================

core.num_threads = THREADS

_here = os.path.dirname(os.path.abspath(__file__))

# 若 mvtools 未被自动加载，则加载与本脚本同目录下的插件 dll（兼容各版本 VapourSynth）
try:
    _mv = core.mv
except AttributeError:
    for _f in os.listdir(_here):
        if _f.lower().endswith('.dll') and 'mvtools' in _f.lower():
            try:
                core.std.LoadPlugin(os.path.join(_here, _f), altsearchpath=True)
            except vs.Error:
                pass

clip = video_in
try:
    # container_fps 可能为 0 或缺失，仅在有效时校正帧率，避免 AssumeFPS(0) 异常
    if container_fps > 1:
        clip = core.std.AssumeFPS(clip, fpsnum=int(container_fps * 1000), fpsden=1000)
except (NameError, vs.Error):
    pass

# 源帧率已接近/达到目标帧率时直接输出，避免无效计算（对低性能机器尤为重要）
if clip.fps_num >= DST_FPS * clip.fps_den * 0.9:
    clip.set_output()
else:
    sup  = core.mv.Super(clip, pel=2, sharp=2, hpad=16, vpad=16)
    bv   = core.mv.Analyse(sup, isb=True,  blksize=8, overlap=2, chroma=True, search=4, searchparam=2, dct=1)
    fv   = core.mv.Analyse(sup, isb=False, blksize=8, overlap=2, chroma=True, search=4, searchparam=2, dct=1)
    clip = core.mv.BlockFPS(clip, sup, bv, fv, num=DST_FPS, den=1)
    clip.set_output()