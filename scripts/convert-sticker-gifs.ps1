<#
.SYNOPSIS
将短视频转换为适合动态表情包的无限循环 GIF。

.DESCRIPTION
脚本会为每个视频生成独立调色板，并可根据首尾 SSIM 自动选择直接循环或首尾融合。
默认拒绝覆盖已有文件。目录输入只扫描当前层，不递归。

.PARAMETER InputPath
一个或多个视频文件或包含视频的目录。

.PARAMETER OutputDirectory
GIF 输出目录。

.PARAMETER LoopMode
Auto、Direct 或 Crossfade。Auto 默认以 0.97 SSIM 为分界。

.PARAMETER Overwrite
允许覆盖目标 GIF。只有用户明确授权替换时才使用。

.EXAMPLE
pwsh -File scripts/convert-sticker-gifs.ps1 -InputPath "D:\stickers\video" -OutputDirectory "D:\stickers\GIF\final" -LoopMode Auto -Json
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory, Position = 0)]
    [string[]]$InputPath,

    [Parameter(Mandatory)]
    [string]$OutputDirectory,

    [ValidateSet('Auto', 'Direct', 'Crossfade')]
    [string]$LoopMode = 'Auto',

    [ValidateRange(64, 2048)]
    [int]$Size = 448,

    [ValidateRange(1, 60)]
    [int]$Fps = 15,

    [ValidateRange(2, 256)]
    [int]$MaxColors = 160,

    [ValidateRange(0.05, 2.0)]
    [double]$FadeSeconds = 0.3,

    [ValidateRange(0.0, 1.0)]
    [double]$SsimThreshold = 0.97,

    [string]$FfmpegPath,

    [string]$FfprobePath,

    [switch]$Overwrite,

    [switch]$Json
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
if (Get-Variable -Name PSNativeCommandUseErrorActionPreference -ErrorAction SilentlyContinue) {
    $PSNativeCommandUseErrorActionPreference = $false
}

$invariantCulture = [System.Globalization.CultureInfo]::InvariantCulture
$supportedExtensions = @('.mp4', '.mov', '.mkv', '.webm', '.m4v')

function Resolve-MediaTool {
    param(
        [string]$ExplicitPath,
        [Parameter(Mandatory)]
        [string]$CommandName
    )

    if (-not [string]::IsNullOrWhiteSpace($ExplicitPath)) {
        $resolved = Resolve-Path -LiteralPath $ExplicitPath -ErrorAction Stop
        $item = Get-Item -LiteralPath $resolved.Path
        if ($item.PSIsContainer) {
            throw "$CommandName 路径不能是目录：$($item.FullName)"
        }
        return $item.FullName
    }

    $command = Get-Command "$CommandName.exe" -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $command) {
        $command = Get-Command $CommandName -ErrorAction SilentlyContinue | Select-Object -First 1
    }
    if (-not $command) {
        throw "找不到 $CommandName。请安装 FFmpeg，或传入对应的显式路径。"
    }
    return $command.Source
}

function Invoke-JsonProbe {
    param(
        [Parameter(Mandatory)]
        [string]$MediaPath,
        [Parameter(Mandatory)]
        [string]$ProbeExe
    )

    $probeArguments = @(
        '-v', 'error',
        '-count_frames',
        '-show_entries', 'format=duration,size:stream=codec_name,codec_type,width,height,r_frame_rate,nb_frames,nb_read_frames',
        '-of', 'json',
        $MediaPath
    )
    $probeText = & $ProbeExe @probeArguments | Out-String
    if ($LASTEXITCODE -ne 0) {
        throw "ffprobe 检查失败：$MediaPath"
    }
    return $probeText | ConvertFrom-Json
}

function Get-VideoStream {
    param([Parameter(Mandatory)]$Probe)

    $stream = @($Probe.streams | Where-Object { $_.codec_type -eq 'video' } | Select-Object -First 1)
    if ($stream.Count -ne 1) {
        throw '媒体文件没有可用的视频流。'
    }
    return $stream[0]
}

function Get-FrameCount {
    param([Parameter(Mandatory)]$Stream)

    foreach ($candidate in @($Stream.nb_read_frames, $Stream.nb_frames)) {
        $parsed = 0
        if ($null -ne $candidate -and [int]::TryParse([string]$candidate, [ref]$parsed) -and $parsed -gt 0) {
            return $parsed
        }
    }
    return 0
}

function Get-FirstLastSsim {
    param(
        [Parameter(Mandatory)]
        [string]$MediaPath,
        [Parameter(Mandatory)]
        [int]$FrameCount,
        [Parameter(Mandatory)]
        [string]$FfmpegExe
    )

    if ($FrameCount -lt 2) {
        return $null
    }

    $lastIndex = $FrameCount - 1
    $filter = "[0:v]split=2[a][b];[a]select=eq(n\,0),format=yuv420p[first];[b]select=eq(n\,$lastIndex),format=yuv420p[last];[first][last]ssim"
    $ssimArguments = @(
        '-hide_banner',
        '-i', $MediaPath,
        '-filter_complex', $filter,
        '-frames:v', '1',
        '-an',
        '-f', 'null',
        '-'
    )
    $log = (& $FfmpegExe @ssimArguments 2>&1) | Out-String
    if ($LASTEXITCODE -ne 0) {
        throw "首尾 SSIM 计算失败：$MediaPath"
    }

    $match = [regex]::Match($log, 'All:([0-9.]+)')
    if (-not $match.Success) {
        return $null
    }
    return [double]::Parse($match.Groups[1].Value, $invariantCulture)
}

function Get-GifLoopCount {
    param([Parameter(Mandatory)][string]$GifPath)

    $bytes = [System.IO.File]::ReadAllBytes($GifPath)
    $ascii = [System.Text.Encoding]::ASCII.GetString($bytes)
    $index = $ascii.IndexOf('NETSCAPE2.0', [System.StringComparison]::Ordinal)
    if ($index -lt 0 -or ($index + 14) -ge $bytes.Length) {
        return $null
    }
    return [int]$bytes[$index + 13] + 256 * [int]$bytes[$index + 14]
}

$ffmpegExe = Resolve-MediaTool -ExplicitPath $FfmpegPath -CommandName 'ffmpeg'
$ffprobeExe = Resolve-MediaTool -ExplicitPath $FfprobePath -CommandName 'ffprobe'

$inputFiles = @()
foreach ($pathEntry in $InputPath) {
    $resolvedEntries = @(Resolve-Path -LiteralPath $pathEntry -ErrorAction Stop)
    foreach ($resolvedEntry in $resolvedEntries) {
        $item = Get-Item -LiteralPath $resolvedEntry.Path
        if ($item.PSIsContainer) {
            $inputFiles += Get-ChildItem -LiteralPath $item.FullName -File |
                Where-Object { $supportedExtensions -contains $_.Extension.ToLowerInvariant() }
        } elseif ($supportedExtensions -contains $item.Extension.ToLowerInvariant()) {
            $inputFiles += $item
        } else {
            throw "不支持的输入格式：$($item.FullName)"
        }
    }
}

$inputFiles = @($inputFiles | Sort-Object FullName -Unique)
if ($inputFiles.Count -eq 0) {
    throw '没有找到可转换的视频文件。'
}

if (Test-Path -LiteralPath $OutputDirectory) {
    $outputItem = Get-Item -LiteralPath $OutputDirectory
    if (-not $outputItem.PSIsContainer) {
        throw "输出路径不是目录：$OutputDirectory"
    }
} else {
    $outputItem = New-Item -ItemType Directory -Path $OutputDirectory
}
$outputDirectoryFull = $outputItem.FullName

$plans = foreach ($inputFile in $inputFiles) {
    [pscustomobject]@{
        Input = $inputFile
        Output = Join-Path $outputDirectoryFull ($inputFile.BaseName + '.gif')
    }
}

$duplicateOutputs = @($plans | Group-Object Output | Where-Object { $_.Count -gt 1 })
if ($duplicateOutputs.Count -gt 0) {
    throw "多个输入会生成同名 GIF：$($duplicateOutputs[0].Name)"
}

if (-not $Overwrite) {
    $existing = @($plans | Where-Object { Test-Path -LiteralPath $_.Output })
    if ($existing.Count -gt 0) {
        throw "拒绝覆盖已有文件：$($existing[0].Output)"
    }
}

$writeOption = if ($Overwrite) { '-y' } else { '-n' }
$fadeText = $FadeSeconds.ToString('0.######', $invariantCulture)
$sizeFilter = "scale=$($Size):$($Size):force_original_aspect_ratio=decrease:flags=lanczos,pad=$($Size):$($Size):(ow-iw)/2:(oh-ih)/2:color=white"
$results = @()

foreach ($plan in $plans) {
    $inputProbe = Invoke-JsonProbe -MediaPath $plan.Input.FullName -ProbeExe $ffprobeExe
    $inputStream = Get-VideoStream -Probe $inputProbe
    $frameCount = Get-FrameCount -Stream $inputStream
    $duration = [double]::Parse([string]$inputProbe.format.duration, $invariantCulture)
    $inputSsim = Get-FirstLastSsim -MediaPath $plan.Input.FullName -FrameCount $frameCount -FfmpegExe $ffmpegExe

    $selectedMode = $LoopMode
    if ($selectedMode -eq 'Auto') {
        $selectedMode = if ($null -ne $inputSsim -and $inputSsim -ge $SsimThreshold) { 'Direct' } else { 'Crossfade' }
    }

    if ($selectedMode -eq 'Direct') {
        $filter = "[0:v]fps=$Fps,$sizeFilter,split[v0][v1];[v0]palettegen=max_colors=$($MaxColors):reserve_transparent=0:stats_mode=diff[p];[v1][p]paletteuse=dither=bayer:bayer_scale=3:diff_mode=rectangle[out]"
    } else {
        $mainEnd = $duration - $FadeSeconds
        if ($mainEnd -le 0) {
            throw "视频短于融合时长，无法处理：$($plan.Input.FullName)"
        }
        $mainEndText = $mainEnd.ToString('0.######', $invariantCulture)
        $durationText = $duration.ToString('0.######', $invariantCulture)
        $filter = "[0:v]fps=24,format=yuv444p,settb=AVTB,split=3[s0][s1][s2];[s0]trim=start=0:end=$mainEndText,setpts=PTS-STARTPTS[main];[s1]trim=start=$($mainEndText):end=$durationText,setpts=PTS-STARTPTS[tail];[s2]trim=start_frame=0:end_frame=1,setpts=PTS-STARTPTS,loop=loop=-1:size=1:start=0,trim=duration=$fadeText,setpts=PTS-STARTPTS[head];[tail][head]xfade=transition=fade:duration=$($fadeText):offset=0[blend];[main][blend]concat=n=2:v=1:a=0,fps=$Fps,$sizeFilter,split[v0][v1];[v0]palettegen=max_colors=$($MaxColors):reserve_transparent=0:stats_mode=diff[p];[v1][p]paletteuse=dither=bayer:bayer_scale=3:diff_mode=rectangle[out]"
    }

    $convertArguments = @(
        '-hide_banner',
        '-loglevel', 'error',
        '-i', $plan.Input.FullName,
        '-filter_complex', $filter,
        '-map', '[out]',
        '-an',
        '-loop', '0',
        $writeOption,
        $plan.Output
    )
    & $ffmpegExe @convertArguments
    if ($LASTEXITCODE -ne 0) {
        throw "GIF 转换失败：$($plan.Input.FullName)"
    }

    $gifProbe = Invoke-JsonProbe -MediaPath $plan.Output -ProbeExe $ffprobeExe
    $gifStream = Get-VideoStream -Probe $gifProbe
    $gifFrameCount = Get-FrameCount -Stream $gifStream
    $gifItem = Get-Item -LiteralPath $plan.Output
    $loopCount = Get-GifLoopCount -GifPath $gifItem.FullName

    $results += [pscustomobject]@{
        Input = $plan.Input.FullName
        Output = $gifItem.FullName
        LoopMode = $selectedMode
        InputFirstLastSsim = $inputSsim
        Width = [int]$gifStream.width
        Height = [int]$gifStream.height
        FrameRate = [string]$gifStream.r_frame_rate
        Frames = $gifFrameCount
        Duration = [double]::Parse([string]$gifProbe.format.duration, $invariantCulture)
        Megabytes = [Math]::Round($gifItem.Length / 1MB, 3)
        InfiniteLoop = ($loopCount -eq 0)
        SHA256 = (Get-FileHash -LiteralPath $gifItem.FullName -Algorithm SHA256).Hash
    }
}

if ($Json) {
    $results | ConvertTo-Json -Depth 5
} else {
    $results
}
