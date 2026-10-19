# ============================================================
#  mpv + VapourSynth (MVTools) 插帧功能 一键安装脚本 (便携免Python版)
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
$vsPortableDir = Join-Path $mpvDir 'vapoursynth-portable'

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

Info '步骤 0/7  检查运行环境'
if (-not (Test-Path (Join-Path $mpvDir 'mpv.exe'))) {
    Warn "未在 $($mpvDir) 找到 mpv.exe，将继续按此目录处理。"
} else {
    Ok "检测到 mpv 目录: $mpvDir"
}
if (-not [Environment]::Is64BitOperatingSystem) {
    Die '插帧组件仅支持 64 位 Windows，当前系统为 32 位。'
}

# ---------------- 步骤 1: portable_config ----------------
Info '步骤 1/7  准备 portable_config 目录'
if (-not (Test-Path $cfgDir)) {
    New-Item -ItemType Directory -Path $cfgDir -Force | Out-Null
    Ok '已创建 portable_config 文件夹'
} else {
    Ok 'portable_config 已存在，跳过创建'
}
New-Item -ItemType Directory -Path $vsOutDir -Force | Out-Null
Ok "插件/脚本输出目录: $vsOutDir"

# ---------------- 步骤 2: 下载并执行 VapourSynth 便携版 ----------------
Info '步骤 2/7  下载并配置 VapourSynth 便携版'

if ((Test-Path $vsPortableDir) -and (-not $Force)) {
    Ok '已存在 vapoursynth-portable 文件夹，跳过下载。'
} else {
    # 获取最新 Release 的 API 信息
    $apiUrl = 'https://api.github.com/repos/vapoursynth/vapoursynth/releases/latest'
    Write-Host "  正在获取 VapourSynth 最新版本信息..." -ForegroundColor DarkGray
    
    try {
        $releaseInfo = Invoke-RestMethod -Uri $apiUrl -Headers @{ 'User-Agent' = 'mpv-Installer' } -ErrorAction Stop
        # 寻找名字前缀为 Install-Portable 且以 .zip 结尾的附件
        $asset = $releaseInfo.assets | Where-Object { $_.name -like 'Install-Portable-*.zip' } | Select-Object -First 1
        
        if (-not $asset) { throw '在最新 Release 中未找到 Install-Portable-*.zip 文件。' }
        
        $zipPath = Join-Path $env:TEMP $asset.name
        $extractDir = Join-Path $env:TEMP ('vs_extract_' + [guid]::NewGuid().ToString('N'))
        
        Write-Host "  正在下载 $($asset.name)..." -ForegroundColor DarkGray
        Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $zipPath -UseBasicParsing -ErrorAction Stop
        
        Write-Host "  正在解压并提取安装脚本..." -ForegroundColor DarkGray
        Expand-Archive -Path $zipPath -DestinationPath $extractDir -Force
        $ps1Path = Get-ChildItem -Path $extractDir -Filter '*.ps1' -Recurse | Select-Object -First 1
        
        if (-not $ps1Path) { throw "解压后未找到 .ps1 安装脚本。" }
        
        Write-Host "  正在静默执行 VapourSynth 官方安装脚本..." -ForegroundColor DarkGray
        # 使用官方脚本静默安装到 vapoursynth-portable 文件夹
        $vsInstallArgs = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$($ps1Path.FullName)`"", '-TargetFolder', "`"$vsPortableDir`"", '-Unattended')
        $installProc = Start-Process -FilePath 'powershell.exe' -ArgumentList $vsInstallArgs -Wait -PassThru -NoNewWindow
        
        if ($installProc.ExitCode -ne 0) { throw "VapourSynth 安装脚本返回错误码: $($installProc.ExitCode)" }
        
        # 清理临时文件
        Remove-Item $zipPath -Force -ErrorAction SilentlyContinue
        Remove-Item $extractDir -Recurse -Force -ErrorAction SilentlyContinue
        
        Ok 'VapourSynth 便携版下载并解压完成。'
    }
    catch {
        Die "VapourSynth 下载或安装失败：$($_.Exception.Message)"
    }
}

# ---------------- 步骤 3: 注册环境变量 ----------------
Info '步骤 3/7  查找并注册 VSSCRIPT_PATH 环境变量'

# 在便携版目录中递归查找 vsscript.dll
$vsscriptDll = Get-ChildItem -Path $vsPortableDir -Filter 'vsscript.dll' -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1

if (-not $vsscriptDll) {
    Die "在 $vsPortableDir 中未找到 vsscript.dll，安装可能不完整。"
}

$vsDllPath = $vsscriptDll.FullName
$vsDllDir = $vsscriptDll.DirectoryName

# 写入用户环境变量
[Environment]::SetEnvironmentVariable('VSSCRIPT_PATH', $vsDllPath, 'User')
$env:VSSCRIPT_PATH = $vsDllPath

# 将目录加入 PATH（双重保险）
$userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
if (-not $userPath) { $userPath = '' }
if ($userPath -notlike "*$vsDllDir*") {
    [Environment]::SetEnvironmentVariable('Path', "$userPath;$vsDllDir", 'User')
    $env:Path = $env:Path.TrimEnd(';') + ';' + $vsDllDir
}

Ok "VSSCRIPT_PATH 已设置为: $vsDllPath"
Ok "相关目录已加入用户 PATH。"

# ---------------- 步骤 4: MVTools ----------------
function Install-MVTools() {
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

Info '步骤 4/7  检查 MVTools 插件'
$haveMv = $null
if (-not $Force) { $haveMv = Get-ChildItem $vsOutDir -Filter '*.dll' -ErrorAction SilentlyContinue | Where-Object { $_.Name -match 'mvtools' } | Select-Object -First 1 }
if ($haveMv) {
    Ok "已存在插件: $($haveMv.Name)，跳过下载"
} else {
    Install-MVTools
}

# ---------------- 步骤 5: 生成 vpy 插帧脚本 ----------------
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

Info '步骤 5/7  生成插帧脚本 (.vpy)'
foreach ($name in $presets.Keys) {
    $f = Join-Path $vsOutDir $name
    if ((Test-Path $f) -and (-not $Force)) {
        Ok "$name 已存在，跳过"
    } else {
        Write-Vpy $f $presets[$name][0] $presets[$name][1] $presets[$name][2]
        Ok "已生成 $name"
    }
}

# ---------------- 步骤 6: 写入 input.conf ----------------
$inputBlock = @'

# ============ mpv MVTools 插帧 ============
_  ignore  #menu: 视频增强 > 插帧模式 > -
Alt+0 vf clr "" #menu: 视频增强 > 插帧模式 > 关闭 VS-MVTools 插帧
Alt+1 vf set vapoursynth="~~/vs/60fps-lq.vpy" #menu: 视频增强 > 插帧模式 > VS-MVTools LQ
Alt+2 vf set vapoursynth="~~/vs/60fps-mq.vpy" #menu: 视频增强 > 插帧模式 > VS-MVTools MQ
Alt+3 vf set vapoursynth="~~/vs/60fps-hq.vpy" #menu: 视频增强 > 插帧模式 > VS-MVTools HQ
'@

Info '步骤 6/7  写入 input.conf 快捷键'
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

# ---------------- 步骤 7: 生成 readme.txt ----------------
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