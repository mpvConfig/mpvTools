# mpv open-svpflow 插帧 - SVP HQ
import os
import vapoursynth as vs

core = vs.core
_here = os.path.dirname(os.path.abspath(__file__))

DST_FPS = 60
SUPER_OPT = '{"gpu": 1}'
ANALYSE_OPT = '{"block": {"w": 8, "overlap": 2}, "main": {"search": {"distance": 0, "coarse": {"distance": -1, "trymany": true, "bad": {"sad": 2000}}}}, "refine": [{"thsad": 250, "search": {"distance": -1, "satd": true}}]}'
SMOOTH_OPT = '{"rate": {"num": 60, "den": 1, "abs": true}, "algo": 23, "mask": {"cover": 80, "area": 0, "area_sharp": 1.2}, "scene": {"blend": true, "mode": 0, "limits": {"blocks": 50}}}'

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