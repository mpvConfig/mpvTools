# ============================================================
#  mpv + VapourSynth (MVTools / open-svpflow) interpolation one-click installer
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

# ---------------- Output helpers ----------------
function Info($m) { Write-Host "`n=== $m ===" -ForegroundColor Cyan }
function Ok($m)   { Write-Host "  [OK] $m" -ForegroundColor Green }
function Warn($m) { Write-Host "  [!!] $m" -ForegroundColor Yellow }
function Die($m)  { Write-Host "`n[FAILED] $m" -ForegroundColor Red; Wait-Exit 1 }
function Wait-Exit([int]$code) {
    Write-Host ''
    try { if ($Host.Name -match 'ConsoleHost') { $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown') } } catch {}
    exit $code
}
function Write-Utf8NoBom([string]$path, [string]$content) {
    [IO.File]::WriteAllText($path, $content, (New-Object System.Text.UTF8Encoding($false)))
}

# ---------------- Language selection ----------------
function Select-Language {
    $prompt = 'Please enter the language/语言 (zh, zh-TW, en): '
    while ($true) {
        Write-Host ''
        Write-Host $prompt -ForegroundColor Cyan -NoNewline
        $choice = Read-Host
        if ([string]::IsNullOrWhiteSpace($choice)) { $choice = 'en' }
        switch ($choice.Trim().ToLower()) {
            'zh'    { return 'zh' }
            'zh-tw' { return 'zh-TW' }
            'en'    { return 'en' }
            default {
                Warn "Invalid choice: '$choice'. Please enter zh, zh-TW or en."
            }
        }
    }
}

# ---------------- Localization data (only inputBlock & readmeText) ----------------
$i18n = @{}

$i18n['zh'] = @{
    'inputBlock' = @'

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
    'readmeText' = @'
mpv + VapourSynth 插帧说明

MVTools (Alt+1/2/3)：基于运动补偿的传统插帧，兼容性好。
open-svpflow (Alt+4/5/6)：SVP 算法的开源重写版，支持 VapourSynth API 4，性能优于原版 SVPflow。

按 Alt+0 关闭插帧。
播放时按 i 键可查看是否出现 vapoursynth 滤镜和帧率变化。
'@
}

$i18n['zh-TW'] = @{
    'inputBlock' = @'

# ============ mpv MVTools 插幀 ============
_  ignore  #menu: 影片增強 > 插幀模式 > -
Alt+0 vf clr "" #menu: 影片增強 > 插幀模式 > 關閉 VS 插幀
Alt+1 vf set vapoursynth="~~/vs/60fps-lq.vpy" #menu: 影片增強 > 插幀模式 > VS-MVTools LQ
Alt+2 vf set vapoursynth="~~/vs/60fps-mq.vpy" #menu: 影片增強 > 插幀模式 > VS-MVTools MQ
Alt+3 vf set vapoursynth="~~/vs/60fps-hq.vpy" #menu: 影片增強 > 插幀模式 > VS-MVTools HQ

# ============ mpv open-svpflow 插幀 ============
Alt+4 vf set vapoursynth="~~/vs/open-svpflow-lq.vpy" #menu: 影片增強 > 插幀模式 > VS-OPEN-SVP LQ
Alt+5 vf set vapoursynth="~~/vs/open-svpflow-mq.vpy" #menu: 影片增強 > 插幀模式 > VS-OPEN-SVP MQ
Alt+6 vf set vapoursynth="~~/vs/open-svpflow-hq.vpy" #menu: 影片增強 > 插幀模式 > VS-OPEN-SVP HQ
'@
    'readmeText' = @'
mpv + VapourSynth 插幀說明

MVTools (Alt+1/2/3)：基於運動補償的傳統插幀，相容性好。
open-svpflow (Alt+4/5/6)：SVP 演算法的開源重寫版，支援 VapourSynth API 4，效能優於原版 SVPflow。

按 Alt+0 關閉插幀。
播放時按 i 鍵可查看是否出現 vapoursynth 濾鏡和幀率變化。
'@
}

$i18n['en'] = @{
    'inputBlock' = @'

# ============ mpv MVTools Interpolation ============
_  ignore  #menu: Video FX > Interpolation > -
Alt+0 vf clr "" #menu: Video FX > Interpolation > Disable VapourSynth Interpolation
Alt+1 vf set vapoursynth="~~/vs/60fps-lq.vpy" #menu: Video FX > Interpolation > VS-MVTools LQ
Alt+2 vf set vapoursynth="~~/vs/60fps-mq.vpy" #menu: Video FX > Interpolation > VS-MVTools MQ
Alt+3 vf set vapoursynth="~~/vs/60fps-hq.vpy" #menu: Video FX > Interpolation > VS-MVTools HQ

# ============ mpv open-svpflow Interpolation ============
Alt+4 vf set vapoursynth="~~/vs/open-svpflow-lq.vpy" #menu: Video FX > Interpolation > VS-OPEN-SVP LQ
Alt+5 vf set vapoursynth="~~/vs/open-svpflow-mq.vpy" #menu: Video FX > Interpolation > VS-OPEN-SVP MQ
Alt+6 vf set vapoursynth="~~/vs/open-svpflow-hq.vpy" #menu: Video FX > Interpolation > VS-OPEN-SVP HQ
'@
    'readmeText' = @'
mpv + VapourSynth Interpolation Notes

MVTools (Alt+1/2/3): Traditional motion-compensated interpolation with good compatibility.
open-svpflow (Alt+4/5/6): Open-source rewrite of the SVP algorithm, supports VapourSynth API 4, faster than the original SVPflow.

Press Alt+0 to disable interpolation.
Press i during playback to check whether the vapoursynth filter is active and the frame rate has changed.
'@
}

$lang = Select-Language
$inputBlock = $i18n[$lang]['inputBlock']
$readmeText = $i18n[$lang]['readmeText']

# ---------------- Step 0: Environment check ----------------
Write-Host ''
Write-Host '  ======================================================' -ForegroundColor DarkCyan
Write-Host '    mpv + VapourSynth Interpolation (MVTools / open-svpflow) One-Click Installer' -ForegroundColor DarkCyan
Write-Host '  ======================================================' -ForegroundColor DarkCyan

Info 'Step 1/7  Checking environment'
if (-not (Test-Path (Join-Path $mpvDir 'mpv.exe'))) {
    Warn "mpv.exe not found in $($mpvDir); continuing with this directory anyway."
} else {
    Ok "Detected mpv directory: $mpvDir"
}
if (-not [Environment]::Is64BitOperatingSystem) {
    Die 'Interpolation components only support 64-bit Windows; current system is 32-bit.'
}

# ---------------- Step 2: portable_config ----------------
Info 'Step 2/7  Preparing portable_config directory'
if (-not (Test-Path $cfgDir)) {
    New-Item -ItemType Directory -Path $cfgDir -Force | Out-Null
    Ok 'Created portable_config folder'
} else {
    Ok 'portable_config already exists, skipping creation'
}
New-Item -ItemType Directory -Path $vsOutDir -Force | Out-Null
Ok "Plugin/script output directory: $vsOutDir"

# ---------------- Step 3: VapourSynth portable (flattened) ----------------
Info 'Step 3/7  Downloading and configuring VapourSynth (flattened mode)'

if ((Test-Path (Join-Path $mpvDir 'python.exe')) -and (-not $Force)) {
    Ok 'VapourSynth core files already exist in this directory, skipping download.'
} else {
    $apiUrl = 'https://api.github.com/repos/vapoursynth/vapoursynth/releases/latest'
    Write-Host '  Fetching latest VapourSynth version info...' -ForegroundColor DarkGray

    try {
        $releaseInfo = Invoke-RestMethod -Uri $apiUrl -Headers @{ 'User-Agent' = 'mpv-Installer' } -ErrorAction Stop
        $asset = $releaseInfo.assets | Where-Object { $_.name -like 'Install-Portable-*.zip' } | Select-Object -First 1

        if (-not $asset) { throw 'No Install-Portable-*.zip found in the latest Release.' }

        $zipPath = Join-Path $env:TEMP $asset.name
        $extractDir = Join-Path $env:TEMP ('vs_extract_' + [guid]::NewGuid().ToString('N'))

        Write-Host "  Downloading $($asset.name)..." -ForegroundColor DarkGray
        Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $zipPath -UseBasicParsing -ErrorAction Stop

        Write-Host '  Extracting and locating install script...' -ForegroundColor DarkGray
        Expand-Archive -Path $zipPath -DestinationPath $extractDir -Force
        $ps1Path = Get-ChildItem -Path $extractDir -Filter '*.ps1' -Recurse | Select-Object -First 1

        if (-not $ps1Path) { throw 'No .ps1 install script found after extraction.' }

        Write-Host '  Installing VapourSynth silently...' -ForegroundColor DarkGray
        $vsInstallArgs = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$($ps1Path.FullName)`"", '-TargetFolder', "`"$vsPortableDir`"", '-Unattended')
        $installProc = Start-Process -FilePath 'powershell.exe' -ArgumentList $vsInstallArgs -Wait -PassThru -NoNewWindow

        if ($installProc.ExitCode -ne 0) { throw "VapourSynth install script returned error code: $($installProc.ExitCode)" }

        Write-Host '  Flattening files into the mpv root directory...' -ForegroundColor DarkGray
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
        Ok 'VapourSynth core files flattened into current directory.'
    }
    catch {
        Die "VapourSynth download or installation failed: $($_.Exception.Message)"
    }
}

# ---------------- Step 4: vsscript.dll ----------------
Info 'Step 4/7  Downloading and placing vsscript.dll'

$vsscriptDllPath = Join-Path $mpvDir 'vsscript.dll'

if ((Test-Path $vsscriptDllPath) -and (-not $Force)) {
    Ok 'vsscript.dll already exists in this directory, skipping download.'
} else {
    # issue https://github.com/vapoursynth/vapoursynth/issues/1264
    $dllUrl = 'https://github.com/mpvConfig/mpvTools/raw/refs/heads/main/vs/vsscript.dll.zip'
    $tmpZip = Join-Path $env:TEMP ('vsscript_' + [guid]::NewGuid().ToString('N') + '.zip')
    $extractDllDir = Join-Path $env:TEMP ('vsscript_extract_' + [guid]::NewGuid().ToString('N'))

    try {
        Write-Host '  Downloading vsscript.dll.zip from the specified link...' -ForegroundColor DarkGray
        Invoke-WebRequest -Uri $dllUrl -OutFile $tmpZip -UseBasicParsing -ErrorAction Stop

        Write-Host '  Extracting...' -ForegroundColor DarkGray
        Expand-Archive -Path $tmpZip -DestinationPath $extractDllDir -Force

        $extractedDll = Get-ChildItem -Path $extractDllDir -Filter 'vsscript.dll' -Recurse | Select-Object -First 1

        if ($extractedDll) {
            Move-Item -Path $extractedDll.FullName -Destination $vsscriptDllPath -Force -ErrorAction Stop
            Ok 'vsscript.dll placed successfully alongside mpv.'
        } else {
            throw 'vsscript.dll not found after extraction.'
        }
    }
    catch {
        Warn "Automatic download of vsscript.dll failed: $($_.Exception.Message)"
        Warn "Please download and extract manually to: $vsscriptDllPath"
    }
    finally {
        if (Test-Path $tmpZip) { Remove-Item $tmpZip -Force -ErrorAction SilentlyContinue }
        if (Test-Path $extractDllDir) { Remove-Item $extractDllDir -Recurse -Force -ErrorAction SilentlyContinue }
    }
}

# ---------------- Step 5: MVTools + open-svpflow ----------------
Info 'Step 5/7  Checking MVTools and open-svpflow plugins'

# MVTools (download zip and extract)
$haveMv = $null
if (-not $Force) { $haveMv = Get-ChildItem $vsOutDir -Filter '*mvtools*' -ErrorAction SilentlyContinue | Select-Object -First 1 }
if ($haveMv) {
    Ok "MVTools plugin already exists: $($haveMv.Name), skipping download"
} else {
    $mvUrl = 'https://github.com/mpvConfig/mpvTools/raw/refs/heads/main/vs/libmvtools.zip'
    $tmpMvZip = Join-Path $env:TEMP ('libmvtools_' + [guid]::NewGuid().ToString('N') + '.zip')
    $extractMvDir = Join-Path $env:TEMP ('libmvtools_extract_' + [guid]::NewGuid().ToString('N'))
    try {
        Write-Host '  Downloading libmvtools.zip...' -ForegroundColor DarkGray
        Invoke-WebRequest -Uri $mvUrl -OutFile $tmpMvZip -UseBasicParsing -ErrorAction Stop
        Expand-Archive -Path $tmpMvZip -DestinationPath $extractMvDir -Force

        $mvDlls = Get-ChildItem -Path $extractMvDir -Filter '*.dll' -Recurse
        if ($mvDlls) {
            foreach ($dll in $mvDlls) {
                Copy-Item -Path $dll.FullName -Destination (Join-Path $vsOutDir $dll.Name) -Force
            }
            Ok 'Extracted and installed mvtools.dll'
        } else {
            throw 'No DLL files found in the archive.'
        }
    } catch {
        Warn "mvtools.zip download or extraction failed: $($_.Exception.Message)"
    } finally {
        if (Test-Path $tmpMvZip) { Remove-Item $tmpMvZip -Force -ErrorAction SilentlyContinue }
        if (Test-Path $extractMvDir) { Remove-Item $extractMvDir -Recurse -Force -ErrorAction SilentlyContinue }
    }
}

# open-svpflow (full extraction)
$haveSvp = $null
if (-not $Force) { $haveSvp = Get-ChildItem $vsOutDir -Filter 'svpflow*_vs.dll' -ErrorAction SilentlyContinue }
if ($haveSvp -and $haveSvp.Count -ge 2) {
    Ok 'open-svpflow plugin already exists, skipping download'
} else {
    Write-Host '  Fetching latest open-svpflow version info...' -ForegroundColor DarkGray
    $svpApiUrl = 'https://api.github.com/repos/Z1xus/open-svpflow/releases/latest'
    try {
        $svpRelease = Invoke-RestMethod -Uri $svpApiUrl -Headers @{ 'User-Agent' = 'mpv-Installer' } -ErrorAction Stop
        $svpAsset = $svpRelease.assets | Where-Object {
            $_.name -match 'windows|win64' -and $_.name -match '\.zip$'
        } | Select-Object -First 1

        if (-not $svpAsset) {
            $svpAsset = $svpRelease.assets | Where-Object { $_.name -match 'svpflow' -and $_.name -match '\.zip$' } | Select-Object -First 1
        }
        if (-not $svpAsset) { throw 'No Windows zip asset found in the latest Release.' }

        $tmpSvpZip = Join-Path $env:TEMP ('open-svpflow_' + [guid]::NewGuid().ToString('N') + '.zip')
        $extractSvpDir = Join-Path $env:TEMP ('open-svpflow_extract_' + [guid]::NewGuid().ToString('N'))

        Write-Host "  Downloading $($svpAsset.name)..." -ForegroundColor DarkGray
        Invoke-WebRequest -Uri $svpAsset.browser_download_url -OutFile $tmpSvpZip -UseBasicParsing -ErrorAction Stop
        Expand-Archive -Path $tmpSvpZip -DestinationPath $extractSvpDir -Force

        # Copy all extracted files into the vs directory
        Copy-Item -Path "$extractSvpDir\*" -Destination $vsOutDir -Recurse -Force
        Ok 'All open-svpflow files extracted into the vs directory.'
    } catch {
        Warn "open-svpflow download or extraction failed: $($_.Exception.Message)"
        Warn "Please download the Windows build manually from https://github.com/Z1xus/open-svpflow/releases, extract it and place it into: $vsOutDir"
    } finally {
        if (Test-Path $tmpSvpZip) { Remove-Item $tmpSvpZip -Force -ErrorAction SilentlyContinue }
        if (Test-Path $extractSvpDir) { Remove-Item $extractSvpDir -Recurse -Force -ErrorAction SilentlyContinue }
    }
}

# ---------------- Step 6: vpy interpolation scripts ----------------
Info 'Step 6/7  Downloading interpolation scripts (.vpy)'

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
        Ok "$file already exists, skipping download"
    } else {
        try {
            Write-Host "  Downloading $file..." -ForegroundColor DarkGray
            Invoke-WebRequest -Uri ($baseUrl + $file) -OutFile $destPath -UseBasicParsing -ErrorAction Stop
            Ok "Downloaded $file"
        } catch {
            Warn "Failed to download $file`: $($_.Exception.Message)"
        }
    }
}

# ---------------- Step 7: input.conf and readme ----------------
Info 'Step 7/7  Writing configuration and notes'
if (Test-Path $inputConf) {
    $existing = ''
    try { $existing = [IO.File]::ReadAllText($inputConf) } catch {}
    if ($existing -match 'open-svpflow-lq\.vpy') { Ok 'input.conf already contains interpolation hotkeys, skipping' }
    else {
        Copy-Item $inputConf "$inputConf.bak_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
        [IO.File]::AppendAllText($inputConf, $inputBlock, (New-Object System.Text.UTF8Encoding($false)))
        Ok 'Appended hotkeys to input.conf'
    }
} else {
    Write-Utf8NoBom $inputConf ($inputBlock.TrimStart("`r","`n") + "`r`n")
    Ok 'Created input.conf and wrote hotkeys'
}

[IO.File]::WriteAllText($readme, $readmeText, (New-Object System.Text.UTF8Encoding($false)))
Ok 'Generated readme.txt'

# ---------------- Step 7: Done ----------------
Write-Host ''
Write-Host '  ======================================================' -ForegroundColor Green
Write-Host '    Installation complete!' -ForegroundColor Green
Write-Host '    MVTools: Alt+1(LQ) Alt+2(MQ) Alt+3(HQ)' -ForegroundColor Green
Write-Host '    open-svpflow: Alt+4(LQ) Alt+5(MQ) Alt+6(HQ)' -ForegroundColor Green
Write-Host '  ======================================================' -ForegroundColor Green
Write-Host '    Enjoy! Press any key to close' -ForegroundColor Green
Wait-Exit 0