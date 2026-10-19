# ============================================================
#  mpv + VapourSynth (MVTools) 插帧功能 一键安装脚本 (终极防闪退版)
# ============================================================
#requires -Version 5.1
param(
    [switch]$Elevated,
    [switch]$Force
)

$ErrorActionPreference = 'Stop'
try { [Console]::OutputEncoding = [Text.Encoding]::UTF8 } catch {}

$mpvDir    = $PSScriptRoot
$cfgDir    = Join-Path $mpvDir 'portable_config'
$vsOutDir  = Join-Path $cfgDir 'vs'
$inputConf = Join-Path $cfgDir 'input.conf'
$readme    = Join-Path $mpvDir 'readme.txt'

# ---------------- 输出辅助 ----------------
function Info($m) { Write-Host "`n=== $m ===" -ForegroundColor Cyan }
function Ok($m)   { Write-Host "  [OK] $m" -ForegroundColor Green }
function Warn($m) { Write-Host "  [!!] $m" -ForegroundColor Yellow }
function Die($m)  { Write-Host "`n[失败] $m" -ForegroundColor Red; Wait-Exit 1 }
function Wait-Exit([int]$code) {
    Write-Host ''
    try { if ($Host.Name -match 'ConsoleHost') { $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown') } } catch {}
    exit $code
}
function Write-Utf8NoBom([string]$path, [string]$content) {
    [IO.File]::WriteAllText($path, $content, (New-Object System.Text.UTF8Encoding($false)))
}

# ---------------- 步骤 0: 环境检查 ----------------
Write-Host ''
Write-Host '  ======================================================' -ForegroundColor DarkCyan
Write-Host '    mpv + VapourSynth (MVTools) 插帧功能 一键安装' -ForegroundColor DarkCyan
Write-Host '  ======================================================' -ForegroundColor DarkCyan

Info '步骤 0/8  检查运行环境'
if (-not (Test-Path (Join-Path $mpvDir 'mpv.exe'))) {
    Warn "未在 $($mpvDir) 找到 mpv.exe，将继续按此目录处理。"
} else {
    Ok "检测到 mpv 目录: $mpvDir"
}
if (-not [Environment]::Is64BitOperatingSystem) {
    Die '插帧组件仅支持 64 位 Windows，当前系统为 32 位。'
}

# ---------------- 步骤 1: portable_config ----------------
Info '步骤 1/8  准备 portable_config 目录'
if (-not (Test-Path $cfgDir)) {
    New-Item -ItemType Directory -Path $cfgDir -Force | Out-Null
    Ok '已创建 portable_config 文件夹'
} else {
    Ok 'portable_config 已存在，跳过创建'
}
New-Item -ItemType Directory -Path $vsOutDir -Force | Out-Null
Ok "插件/脚本输出目录: $vsOutDir"

# ---------------- 步骤 2: Python ----------------
function Find-Python {
    $cand = @{}
    if (Get-Command py -ErrorAction SilentlyContinue) {
        try { $e = (& py -3 -c "import sys;print(sys.executable)" 2>$null); if ($LASTEXITCODE -eq 0 -and $e) { $cand[$e.Trim()] = 1 } } catch {}
    }
    if (Get-Command python -ErrorAction SilentlyContinue) {
        try { $e = (& python -c "import sys;print(sys.executable)" 2>$null); if ($LASTEXITCODE -eq 0 -and $e) { $cand[$e.Trim()] = 1 } } catch {}
    }
    foreach ($ver in @('314','313','312','311','310')) {
        foreach ($p in @(
            "$env:LocalAppData\Programs\Python\Python$ver\python.exe",
            "$env:ProgramFiles\Python$ver\python.exe",
            "${env:ProgramFiles(x86)}\Python$ver\python.exe")) {
            if (Test-Path $p) { $cand[$p] = 1 }
        }
    }
    $best = $null; $bestVer = $null
    foreach ($exe in $cand.Keys) {
        try { 
            $v = & $exe -c "import sys;print('%d.%d' % sys.version_info[:2])" 2>$null
            if ($LASTEXITCODE -ne 0 -or -not $v) { continue }
            $vv = [version]$v.Trim()
            if ($vv -ge [version]'3.10' -and (-not $bestVer -or $vv -gt $bestVer)) { $best = $exe; $bestVer = $vv }
        } catch {}
    }
    return @{ Exe = $best; Version = $bestVer }
}

Info '步骤 2/8  检查 Python (3.10 或更高版本)'
$pyInfo = Find-Python
if (-not $pyInfo.Exe) {
    Die '未找到可用的 Python 3.10+，请先去 python.org 安装。'
}
$py = $pyInfo.Exe
Ok "Python: $py (v$($pyInfo.Version))"

# ---------------- 步骤 3: 检查并自动安装 VapourSynth ----------------
Info '步骤 3/8  检查并安装 VapourSynth'

# 安全的测试函数，防止 PowerShell 因为 Python 的报错输出而强制闪退
function Test-VSImport([string]$exe) {
    try {
        $null = & $exe -c "import vapoursynth" 2>&1
        return ($LASTEXITCODE -eq 0)
    } catch {
        return $false
    }
}

if (Test-VSImport $py) {
    Ok 'VapourSynth 已安装且可正常导入，跳过安装。'
} else {
    Warn '当前 Python 环境无法导入 VapourSynth，正在通过清华源自动下载安装...'
    
    # 使用 Start-Process 调用 pip，加入清华源
    $pipArgs = @('-m', 'pip', 'install', '--upgrade', 'vapoursynth', '-i', 'https://pypi.tuna.tsinghua.edu.cn/simple')
    $proc = Start-Process -FilePath $py -ArgumentList $pipArgs -Wait -PassThru -NoNewWindow
    
    if ($proc.ExitCode -ne 0) {
        Die "VapourSynth 安装失败 (pip 退出码 $($proc.ExitCode))。请检查网络或手动安装。"
    }

    # 再次测试导入
    if (-not (Test-VSImport $py)) {
        Die 'VapourSynth 安装后仍无法导入，可能是缺少 VC++ 运行库 (vcruntime140.dll)。'
    }
    Ok 'VapourSynth 已成功下载并安装！'

    # 执行系统级注册
    Info '正在注册 VapourSynth 环境变量...'
    $regArgs = @('-m', 'vapoursynth', 'register-install')
    $regProc = Start-Process -FilePath $py -ArgumentList $regArgs -Wait -PassThru -NoNewWindow
    
    if ($regProc.ExitCode -eq 0) {
        Ok 'VapourSynth 环境注册成功。'
    } else {
        Warn '环境注册失败，mpv 可能找不到 VapourSynth。'
    }
}

# ---------------- 步骤 4: 环境变量补充 ----------------
function Set-VSEnv([string]$exe) {
    $dirs = @(Split-Path $exe)
    try {
        $purelib = (& $exe -c "import sysconfig;print(sysconfig.get_path('purelib'))").Trim()
        $vss = Get-ChildItem (Join-Path $purelib 'vapoursynth') -Recurse -Filter 'vsscript.dll' -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($vss) { $dirs += $vss.DirectoryName }
    } catch {}
    $userPath = [Environment]::GetEnvironmentVariable('Path','User')
    if (-not $userPath) { $userPath = '' }
    $added = @()
    foreach ($d in $dirs) {
        if ($d -and ($userPath -split ';') -notcontains $d) {
            $userPath = ($userPath.TrimEnd(';') + ';' + $d).TrimStart(';')
            $added += $d
        }
    }
    if ($added.Count -gt 0) {
        [Environment]::SetEnvironmentVariable('Path', $userPath, 'User')
        $env:Path = $env:Path.TrimEnd(';') + ';' + ($added -join ';')
        Ok ('已加入用户 PATH: ' + ($added -join ' ; '))
    } else {
        Ok '用户 PATH 已包含所需目录，跳过'
    }
}
Info '步骤 4/8  配置环境变量'
Set-VSEnv $py

# ---------------- 步骤 5: MVTools ----------------
function Install-MVTools([string]$exe) {
    Info '安装 MVTools 插件（直链下载模式）'
    $url = 'https://github.com/mpvConfig/mpvTools/raw/refs/heads/main/vs/libmvtools.dll'
    $dllPath = Join-Path $vsOutDir 'mvtools.dll'
    $tmpDll = Join-Path $env:TEMP ('mvtools_' + [guid]::NewGuid().ToString('N') + '.dll')

    try {
        Write-Host "  正在从 GitHub 下载 mvtools.dll..." -ForegroundColor DarkGray
        Invoke-WebRequest -Uri $url -OutFile $tmpDll -UseBasicParsing -ErrorAction Stop

        if ((Test-Path $tmpDll) -and ((Get-Item $tmpDll).Length -gt 50KB)) {
            Move-Item -Path $tmpDll -Destination $dllPath -Force -ErrorAction Stop
            Ok "已成功从指定链接下载并安装 mvtools.dll"
        } else {
            throw "下载的文件大小异常。"
        }
    }
    catch {
        Warn "自动下载 MVTools 失败：$($_.Exception.Message)"
        Warn "请手动下载放到：$vsOutDir"
    }
    finally {
        if (Test-Path $tmpDll) { Remove-Item $tmpDll -Force -ErrorAction SilentlyContinue }
    }
}

Info '步骤 5/8  检查 MVTools 插件'
$haveMv = $null
if (-not $Force) { $haveMv = Get-ChildItem $vsOutDir -Filter '*.dll' -ErrorAction SilentlyContinue | Where-Object { $_.Name -match 'mvtools' } | Select-Object -First 1 }
if ($haveMv) {
    Ok "已存在插件: $($haveMv.Name)，跳过下载"
} else {
    Install-MVTools $py
}

# ---------------- 步骤 6: 生成 vpy 插帧脚本 ----------------
function Write-Vpy([string]$file, [string]$title, [int]$threads, [string]$preset) {
    $content = @"
# mpv MVTools 插帧 - $title 预设
import os
import vapoursynth as vs
core = vs.core
DST_FPS = 60
THREADS = $threads
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
$preset
clip.set_output()
"@
    Write-Utf8NoBom $file $content
}

$presets = @{
    '60fps-lq.vpy' = @('LQ', 2, "sup=core.mv.Super(clip,pel=1,hpad=8,vpad=8)`nbv=core.mv.Analyse(sup,isb=True,blksize=16,chroma=False,search=1)`nfv=core.mv.Analyse(sup,isb=False,blksize=16,chroma=False,search=1)`nclip=core.mv.BlockFPS(clip,sup,bv,fv,num=DST_FPS*1000,den=1000)")
    '60fps-mq.vpy' = @('MQ', 4, "sup=core.mv.Super(clip,pel=2,hpad=8,vpad=8)`nbv=core.mv.Analyse(sup,isb=True,blksize=16,chroma=True,search=3)`nfv=core.mv.Analyse(sup,isb=False,blksize=16,chroma=True,search=3)`nclip=core.mv.BlockFPS(clip,sup,bv,fv,num=DST_FPS*1000,den=1000)")
    '60fps-hq.vpy' = @('HQ', 8, "sup=core.mv.Super(clip,pel=2,sharp=2,hpad=16,vpad=16)`nbv=core.mv.Analyse(sup,isb=True,blksize=8,overlap=2,chroma=True,search=4,dct=1)`nfv=core.mv.Analyse(sup,isb=False,blksize=8,overlap=2,chroma=True,search=4,dct=1)`nclip=core.mv.BlockFPS(clip,sup,bv,fv,num=DST_FPS*1000,den=1000)")
}

Info '步骤 6/8  生成插帧脚本 (.vpy)'
foreach ($name in $presets.Keys) {
    $f = Join-Path $vsOutDir $name
    if ((Test-Path $f) -and (-not $Force)) {
        Ok "$name 已存在，跳过"
    } else {
        Write-Vpy $f $presets[$name][0] $presets[$name][1] $presets[$name][2]
        Ok "已生成 $name"
    }
}

# ---------------- 步骤 7: 写入 input.conf ----------------
$inputBlock = @'

# ============ mpv MVTools 插帧 ============
_  ignore  #menu: 视频增强 > 插帧模式 > -
Alt+0 vf clr "" #menu: 视频增强 > 插帧模式 > 关闭 VS 插帧
Alt+1 vf set vapoursynth="~~/vs/60fps-lq.vpy" #menu: 视频增强 > 插帧模式 > VS 插帧 LQ
Alt+2 vf set vapoursynth="~~/vs/60fps-mq.vpy" #menu: 视频增强 > 插帧模式 > VS 插帧 MQ
Alt+3 vf set vapoursynth="~~/vs/60fps-hq.vpy" #menu: 视频增强 > 插帧模式 > VS 插帧 HQ
'@

Info '步骤 7/8  写入 input.conf 快捷键'
if (Test-Path $inputConf) {
    $existing = ''
    try { $existing = [IO.File]::ReadAllText($inputConf) } catch {}
    if ($existing -match '60fps-lq\.vpy') {
        Ok 'input.conf 已包含快捷键，跳过'
    } else {
        Copy-Item $inputConf "$inputConf.bak_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
        [IO.File]::AppendAllText($inputConf, $inputBlock, (New-Object System.Text.UTF8Encoding($false)))
        Ok '已向 input.conf 追加快捷键'
    }
} else {
    Write-Utf8NoBom $inputConf ($inputBlock.TrimStart("`r","`n") + "`r`n")
    Ok '已新建 input.conf 并写入'
}

# ---------------- 步骤 8: 生成 readme.txt ----------------
$readmeText = @'
mpv + VapourSynth (MVTools) 插帧说明
按 Alt+0 关闭，Alt+1 低画质，Alt+2 中画质，Alt+3 高画质。
播放时按 i 键可查看是否出现 vapoursynth 滤镜和 60fps。
'@
[IO.File]::WriteAllText($readme, $readmeText, (New-Object System.Text.UTF8Encoding($false)))

Write-Host ''
Write-Host '  ======================================================' -ForegroundColor Green
Write-Host '    安装完成！快捷键: Alt+1(LQ) Alt+2(MQ) Alt+3(HQ)' -ForegroundColor Green
Write-Host '  ======================================================' -ForegroundColor Green
Wait-Exit 0