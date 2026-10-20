# ============================================================
#  mpv + VapourSynth (MVTools / open-svpflow) 插帧一键安装脚本
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
Write-Host '    mpv + VapourSynth 插帧 (MVTools / open-svpflow) 一键安装' -ForegroundColor DarkCyan
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

# ---------------- 步骤 2: 下载并执行 VapourSynth 便携版 (平铺) ----------------
Info '步骤 2/7  下载并配置 VapourSynth (平铺模式)'

if ((Test-Path (Join-Path $mpvDir 'python.exe')) -and (-not $Force)) {
    Ok '当前目录已存在 VapourSynth 核心文件，跳过下载。'
} else {
    $apiUrl = 'https://api.github.com/repos/vapoursynth/vapoursynth/releases/latest'
    Write-Host "  正在获取 VapourSynth 最新版本信息..." -ForegroundColor DarkGray
    
    try {
        $releaseInfo = Invoke-RestMethod -Uri $apiUrl -Headers @{ 'User-Agent' = 'mpv-Installer' } -ErrorAction Stop
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
        
        Write-Host "  正在静默安装 VapourSynth..." -ForegroundColor DarkGray
        $vsInstallArgs = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$($ps1Path.FullName)`"", '-TargetFolder', "`"$vsPortableDir`"", '-Unattended')
        $installProc = Start-Process -FilePath 'powershell.exe' -ArgumentList $vsInstallArgs -Wait -PassThru -NoNewWindow
        
        if ($installProc.ExitCode -ne 0) { throw "VapourSynth 安装脚本返回错误码: $($installProc.ExitCode)" }
        
        Write-Host "  正在将文件平铺到 mpv 根目录..." -ForegroundColor DarkGray
        if (Test-Path $vsPortableDir) {
            $sourceItems = Get-ChildItem -Path $vsPortableDir -Force
            foreach ($item in $sourceItems) {
                $destPath = Join-Path $mpvDir $item.Name
                if ($item.PSIsContainer) {
                    Copy-Item -Path $item.FullName -Destination $mpvDir -Recurse -Force -ErrorAction SilentlyContinue
                } else {
                    Copy-Item -Path $item.FullName -Destination $destPath -Force -ErrorAction SilentlyContinue
                }
            }
            Remove-Item -Path $vsPortableDir -Recurse -Force -ErrorAction SilentlyContinue
        }
        Ok 'VapourSynth 核心文件已平铺到当前目录。'
    }
    catch {
        Die "VapourSynth 下载或安装失败：$($_.Exception.Message)"
    }
}

# ---------------- 步骤 3: 下载 vsscript.dll ----------------
Info '步骤 3/7  下载并放置 vsscript.dll'

$vsscriptDllPath = Join-Path $mpvDir 'vsscript.dll'

if ((Test-Path $vsscriptDllPath) -and (-not $Force)) {
    Ok '当前目录已存在 vsscript.dll，跳过下载。'
} else {
    # issue https://github.com/vapoursynth/vapoursynth/issues/1264
    $dllUrl = 'https://github.com/mpvConfig/mpvTools/raw/refs/heads/main/vs/vsscript.dll.zip'
    $tmpZip = Join-Path $env:TEMP ('vsscript_' + [guid]::NewGuid().ToString('N') + '.zip')
    $extractDllDir = Join-Path $env:TEMP ('vsscript_extract_' + [guid]::NewGuid().ToString('N'))

    try {
        Write-Host "  正在从指定链接下载 vsscript.dll.zip..." -ForegroundColor DarkGray
        Invoke-WebRequest -Uri $dllUrl -OutFile $tmpZip -UseBasicParsing -ErrorAction Stop

        Write-Host "  正在解压..." -ForegroundColor DarkGray
        Expand-Archive -Path $tmpZip -DestinationPath $extractDllDir -Force
        
        $extractedDll = Get-ChildItem -Path $extractDllDir -Filter 'vsscript.dll' -Recurse | Select-Object -First 1
        
        if ($extractedDll) {
            Move-Item -Path $extractedDll.FullName -Destination $vsscriptDllPath -Force -ErrorAction Stop
            Ok '已成功将 vsscript.dll 放置在 mpv 同级目录。'
        } else {
            throw "解压后未找到 vsscript.dll。"
        }
    }
    catch {
        Warn "自动下载 vsscript.dll 失败：$($_.Exception.Message)"
        Warn "请手动下载并解压到：$vsscriptDllPath"
    }
    finally {
        if (Test-Path $tmpZip) { Remove-Item $tmpZip -Force -ErrorAction SilentlyContinue }
        if (Test-Path $extractDllDir) { Remove-Item $extractDllDir -Recurse -Force -ErrorAction SilentlyContinue }
    }
}

# ---------------- 步骤 4: MVTools + open-svpflow ----------------
Info '步骤 4/7  检查 MVTools 与 open-svpflow 插件'

# MVTools (改为下载 zip 并解压)
$haveMv = $null
if (-not $Force) { $haveMv = Get-ChildItem $vsOutDir -Filter '*mvtools*' -ErrorAction SilentlyContinue | Select-Object -First 1 }
if ($haveMv) {
    Ok "已存在 MVTools 插件: $($haveMv.Name)，跳过下载"
} else {
    $mvUrl = 'https://github.com/mpvConfig/mpvTools/raw/refs/heads/main/vs/libmvtools.zip'
    $tmpMvZip = Join-Path $env:TEMP ('libmvtools_' + [guid]::NewGuid().ToString('N') + '.zip')
    $extractMvDir = Join-Path $env:TEMP ('libmvtools_extract_' + [guid]::NewGuid().ToString('N'))
    try {
        Write-Host "  正在下载 libmvtools.zip..." -ForegroundColor DarkGray
        Invoke-WebRequest -Uri $mvUrl -OutFile $tmpMvZip -UseBasicParsing -ErrorAction Stop
        Expand-Archive -Path $tmpMvZip -DestinationPath $extractMvDir -Force
        
        $mvDlls = Get-ChildItem -Path $extractMvDir -Filter '*.dll' -Recurse
        if ($mvDlls) {
            foreach ($dll in $mvDlls) {
                Copy-Item -Path $dll.FullName -Destination (Join-Path $vsOutDir $dll.Name) -Force
            }
            Ok '已解压并安装 mvtools.dll'
        } else {
            throw "压缩包中未找到 DLL 文件。"
        }
    } catch {
        Warn "mvtools.zip 下载或解压失败: $($_.Exception.Message)"
    } finally {
        if (Test-Path $tmpMvZip) { Remove-Item $tmpMvZip -Force -ErrorAction SilentlyContinue }
        if (Test-Path $extractMvDir) { Remove-Item $extractMvDir -Recurse -Force -ErrorAction SilentlyContinue }
    }
}

# open-svpflow (全量解压)
$haveSvp = $null
if (-not $Force) { $haveSvp = Get-ChildItem $vsOutDir -Filter 'svpflow*_vs.dll' -ErrorAction SilentlyContinue }
if ($haveSvp -and $haveSvp.Count -ge 2) {
    Ok "已存在 open-svpflow 插件，跳过下载"
} else {
    Write-Host "  正在获取 open-svpflow 最新版本信息..." -ForegroundColor DarkGray
    $svpApiUrl = 'https://api.github.com/repos/Z1xus/open-svpflow/releases/latest'
    try {
        $svpRelease = Invoke-RestMethod -Uri $svpApiUrl -Headers @{ 'User-Agent' = 'mpv-Installer' } -ErrorAction Stop
        $svpAsset = $svpRelease.assets | Where-Object { 
            $_.name -match 'windows|win64' -and $_.name -match '\.zip$' 
        } | Select-Object -First 1
        
        if (-not $svpAsset) {
            $svpAsset = $svpRelease.assets | Where-Object { $_.name -match 'svpflow' -and $_.name -match '\.zip$' } | Select-Object -First 1
        }
        if (-not $svpAsset) { throw '在最新 Release 中未找到适用于 Windows 的 zip 资产。' }

        $tmpSvpZip = Join-Path $env:TEMP ('open-svpflow_' + [guid]::NewGuid().ToString('N') + '.zip')
        $extractSvpDir = Join-Path $env:TEMP ('open-svpflow_extract_' + [guid]::NewGuid().ToString('N'))
        
        Write-Host "  正在下载 $($svpAsset.name)..." -ForegroundColor DarkGray
        Invoke-WebRequest -Uri $svpAsset.browser_download_url -OutFile $tmpSvpZip -UseBasicParsing -ErrorAction Stop
        Expand-Archive -Path $tmpSvpZip -DestinationPath $extractSvpDir -Force

        # 全量拷贝所有解压出来的文件到 vs 目录
        Copy-Item -Path "$extractSvpDir\*" -Destination $vsOutDir -Recurse -Force
        Ok "已将 open-svpflow 的所有文件释放到 vs 目录。"
    } catch {
        Warn "open-svpflow 下载或解压失败: $($_.Exception.Message)"
        Warn "请手动从 https://github.com/Z1xus/open-svpflow/releases 下载 Windows 版本，解压后放入: $vsOutDir"
    } finally {
        if (Test-Path $tmpSvpZip) { Remove-Item $tmpSvpZip -Force -ErrorAction SilentlyContinue }
        if (Test-Path $extractSvpDir) { Remove-Item $extractSvpDir -Recurse -Force -ErrorAction SilentlyContinue }
    }
}

# ---------------- 步骤 5: 下载 vpy 插帧脚本 ----------------
Info '步骤 5/7  下载插帧脚本 (.vpy)'

$vpyFiles = @(
    '60fps-lq.vpy',
    '60fps-mq.vpy',
    '60fps-hq.vpy',
    'open-svpflow-lq.vpy',
    'open-svpflow-mq.vpy',
    'open-svpflow-hq.vpy'
)

$baseUrl = 'https://github.com/mpvConfig/mpvTools/raw/refs/heads/main/vs/'

foreach ($file in $vpyFiles) {
    $destPath = Join-Path $vsOutDir $file
    if ((Test-Path $destPath) -and (-not $Force)) {
        Ok "$file 已存在，跳过下载"
    } else {
        try {
            Write-Host "  正在下载 $file..." -ForegroundColor DarkGray
            Invoke-WebRequest -Uri ($baseUrl + $file) -OutFile $destPath -UseBasicParsing -ErrorAction Stop
            Ok "已下载 $file"
        } catch {
            Warn "$file 下载失败: $($_.Exception.Message)"
        }
    }
}

# ---------------- 步骤 6: 写入 input.conf 和 readme ----------------
$inputBlock = @'

# ============ mpv MVTools 插帧 ============
_  ignore  #menu: 视频增强 > 插帧模式 > -
Alt+0 vf clr "" #menu: 视频增强 > 插帧模式 > 关闭 VS 插帧
Alt+1 vf set vapoursynth="~~/vs/60fps-lq.vpy" #menu: 视频增强 > 插帧模式 > VS-MVTools LQ
Alt+2 vf set vapoursynth="~~/vs/60fps-mq.vpy" #menu: 视频增强 > 插帧模式 > VS-MVTools MQ
Alt+3 vf set vapoursynth="~~/vs/60fps-hq.vpy" #menu: 视频增强 > 插帧模式 > VS-MVTools HQ

# ============ mpv open-svpflow 插帧 ============
Alt+4 vf set vapoursynth="~~/vs/open-svpflow-lq.vpy" #menu: 视频增强 > 插帧模式 > VS-OPEN-SVP LQ
Alt+5 vf set vapoursynth="~~/vs/open-svpflow-mq.vpy" #menu: 视频增强 > 插帧模式 > VS-OPEN-SVP MQ
Alt+6 vf set vapoursynth="~~/vs/open-svpflow-hq.vpy" #menu: 视频增强 > 插帧模式 > VS-OPEN-SVP HQ
'@

Info '步骤 6/7  写入配置和说明'
if (Test-Path $inputConf) {
    $existing = ''
    try { $existing = [IO.File]::ReadAllText($inputConf) } catch {}
    if ($existing -match 'open-svpflow-lq\.vpy') { Ok 'input.conf 已包含插帧快捷键，跳过' }
    else {
        Copy-Item $inputConf "$inputConf.bak_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
        [IO.File]::AppendAllText($inputConf, $inputBlock, (New-Object System.Text.UTF8Encoding($false)))
        Ok '已向 input.conf 追加快捷键'
    }
} else {
    Write-Utf8NoBom $inputConf ($inputBlock.TrimStart("`r","`n") + "`r`n")
    Ok '已新建 input.conf 并写入'
}

$readmeText = @'
mpv + VapourSynth 插帧说明

MVTools (Alt+1/2/3)：基于运动补偿的传统插帧，兼容性好。
open-svpflow (Alt+4/5/6)：SVP 算法的开源重写版，支持 VapourSynth API 4，性能优于原版 SVPflow。

按 Alt+0 关闭插帧。
播放时按 i 键可查看是否出现 vapoursynth 滤镜和帧率变化。
'@
[IO.File]::WriteAllText($readme, $readmeText, (New-Object System.Text.UTF8Encoding($false)))
Ok "已生成 readme.txt"

# ---------------- 步骤 7: 完成 ----------------
Write-Host ''
Write-Host '  ======================================================' -ForegroundColor Green
Write-Host '    安装完成！' -ForegroundColor Green
Write-Host '    MVTools: Alt+1(LQ) Alt+2(MQ) Alt+3(HQ)' -ForegroundColor Green
Write-Host '    open-svpflow: Alt+4(LQ) Alt+5(MQ) Alt+6(HQ)' -ForegroundColor Green
Write-Host '  ======================================================' -ForegroundColor Green
Wait-Exit 0