# mpv open-svpflow 插帧 - SVP MQ
import os
import sys
import vapoursynth as vs

core = vs.core
_here = os.path.dirname(os.path.abspath(__file__))

DST_FPS = 60

# 动态判断 GPU 选项：macOS/Linux 默认走 CPU，避免因缺少 OpenCL 环境导致崩溃
# 如果你的 Linux/macOS 确认支持 OpenCL，可以把下面的 0 改成 1
GPU_MODE = 1 if sys.platform == 'win32' else 0 

SUPER_OPT = '{"pel": 1, "gpu": %d}' % GPU_MODE
ANALYSE_OPT = '{"block": {"w": 16, "overlap": 2}, "main": {"search": {"coarse": {"distance": -1, "trymany": true, "bad": {"sad": 2000}}}}}'
SMOOTH_OPT = '{"rate": {"num": 60, "den": 1, "abs": true}, "algo": 13, "mask": {"area": 100}}'

# 跨平台加载 SVPFlow / open-svpflow 插件
ext = '.dll' if sys.platform == 'win32' else ('.dylib' if sys.platform == 'darwin' else '.so')
for name in ("svpflow1_vs", "svpflow2_vs"):
    dll_path = os.path.join(_here, name + ext)
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