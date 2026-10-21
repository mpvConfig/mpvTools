# mpv open-svpflow 插帧 - SVP MQ
import os
import vapoursynth as vs

core = vs.core
_here = os.path.dirname(os.path.abspath(__file__))

DST_FPS = 60
SUPER_OPT = '{"pel": 2, "scale": {"up": 0, "down": 4}}'
ANALYSE_OPT = '{"block": {"w": 16, "overlap": 2}, "main": {"search": {"type": 2}}}'
SMOOTH_OPT = '{"rate": {"num": 60, "den": 1, "abs": true}, "algo": 13, "mask": {"area": 100}}'

# 加载 SVPFlow / open-svpflow 插件
for dll in ("svpflow1_vs.dll", "svpflow2_vs.dll"):
    dll_path = os.path.join(_here, dll)
    if os.path.isfile(dll_path):
        try:
            core.std.LoadPlugin(dll_path, altsearchpath=True)
        except vs.Error:
            pass

clip = video_in
try:
    if container_fps > 1:
        clip = core.std.AssumeFPS(
            clip,
            fpsnum=int(container_fps * 1000),
            fpsden=1000
        )
except (NameError, vs.Error):
    pass

if clip.fps_num >= DST_FPS * clip.fps_den * 0.9:
    clip.set_output()
else:
    # 强制转换为 SVP 支持的 8-bit YUV420P8 格式
    if clip.format.id != vs.YUV420P8:
        clip = clip.resize.Point(format=vs.YUV420P8, dither_type="random")
    super_result = core.svp1.Super(clip, SUPER_OPT)
    analyse_result = core.svp1.Analyse(
        super_result["clip"],
        super_result["data"],
        clip,
        ANALYSE_OPT
    )
    clip = core.svp2.SmoothFps(
        clip,
        super_result["clip"],
        super_result["data"],
        analyse_result["clip"],
        analyse_result["data"],
        SMOOTH_OPT
    )
    clip.set_output()