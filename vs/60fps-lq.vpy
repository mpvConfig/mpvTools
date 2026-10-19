# mpv MVTools 插帧 - LQ 预设
import os
import vapoursynth as vs
core = vs.core
DST_FPS = 60
THREADS = 2
core.num_threads = THREADS
_here = os.path.dirname(os.path.abspath(__file__))
try:
    _mv = core.mv
except AttributeError:
    for _f in os.listdir(_here):
        if _f.lower().endswith('.dll') and 'mvtools' in _f.lower():
            try: core.std.LoadPlugin(os.path.join(_here, _f), altsearchpath=True)
            except vs.Error: pass
clip = video_in
try: clip = core.std.AssumeFPS(clip, fpsnum=int(container_fps * 1000), fpsden=1000)
except NameError: pass
sup=core.mv.Super(clip,pel=1,hpad=8,vpad=8)
bv=core.mv.Analyse(sup,isb=True,blksize=16,chroma=False,search=1)
fv=core.mv.Analyse(sup,isb=False,blksize=16,chroma=False,search=1)
clip=core.mv.BlockFPS(clip,sup,bv,fv,num=DST_FPS*1000,den=1000)
clip.set_output()