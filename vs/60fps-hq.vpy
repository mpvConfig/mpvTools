# mpv MVTools 插帧 - HQ 预设
import os
import vapoursynth as vs
core = vs.core
DST_FPS = 60
THREADS = 8
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
sup=core.mv.Super(clip,pel=2,sharp=2,hpad=16,vpad=16)
bv=core.mv.Analyse(sup,isb=True,blksize=8,overlap=2,chroma=True,search=4,dct=1)
fv=core.mv.Analyse(sup,isb=False,blksize=8,overlap=2,chroma=True,search=4,dct=1)
clip=core.mv.BlockFPS(clip,sup,bv,fv,num=DST_FPS*1000,den=1000)
clip.set_output()