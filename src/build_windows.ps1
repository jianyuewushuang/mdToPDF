chcp 65001 | Out-Null
Set-Location $PSScriptRoot

$ErrorActionPreference = "Stop"

$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$stylesDir = Join-Path $projectRoot "resources\styles"
$defaultStyle = "eisvogel"

$env:MERMAID_BIN = (Resolve-Path (Join-Path $PSScriptRoot "..\node_modules\.bin\mmdc.cmd")).Path
New-Item -ItemType Directory -Force -Path "../build" | Out-Null

function Resolve-ProjectPath([string]$relative) {
    if ([IO.Path]::IsPathRooted($relative)) { return $relative }
    return [IO.Path]::GetFullPath((Join-Path $projectRoot $relative))
}

# One .conf per style; the file name is the value accepted by `style:`.
$availableStyles = @(
    Get-ChildItem -LiteralPath $stylesDir -Filter "*.conf" -File |
        ForEach-Object { $_.BaseName } | Sort-Object
)
if ($availableStyles.Count -eq 0) {
    throw "在 $stylesDir 下未找到任何样式配置 (*.conf)"
}

function Read-StyleConf([string]$name) {
    $conf = @{
        Template   = $null
        TexInputs  = @()
        Env        = @{}
        Filters    = @()
        ExtraArgs  = @()
    }
    $path = Join-Path $stylesDir ($name + ".conf")
    foreach ($line in (Get-Content -LiteralPath $path -Encoding UTF8)) {
        $line = $line.Trim()
        if ($line -eq "" -or $line.StartsWith("#")) { continue }
        $eq = $line.IndexOf("=")
        if ($eq -lt 1) { throw "样式配置 $path 中有无效行: $line" }
        $key = $line.Substring(0, $eq).Trim()
        $value = $line.Substring($eq + 1).Trim()
        switch -Regex ($key) {
            "^TEMPLATE$"    { $conf.Template = (Resolve-ProjectPath $value); continue }
            "^TEXINPUTS$"   { foreach ($d in ($value -split "\s+")) { if ($d) { $conf.TexInputs += (Resolve-ProjectPath $d) } }; continue }
            "^ENV_[A-Za-z_][A-Za-z0-9_]*$" {
                $conf.Env[($key.Substring(4))] = (Resolve-ProjectPath $value)
                continue
            }
            "^LUA_FILTERS$" { foreach ($f in ($value -split "\s+")) { if ($f) { $conf.Filters += (Resolve-ProjectPath $f) } }; continue }
            "^PANDOC_ARGS$" { foreach ($a in ($value -split "\s+")) { if ($a) { $conf.ExtraArgs += $a } }; continue }
            default         { Write-Warning "忽略未知的样式配置键 '$key' ($path)"; continue }
        }
    }
    if (-not $conf.Template) { throw "样式 '$name' 的配置缺少 TEMPLATE" }
    if (-not (Test-Path -LiteralPath $conf.Template)) {
        throw "样式 '$name' 的模板不存在: $($conf.Template)"
    }
    foreach ($f in $conf.Filters) {
        if (-not (Test-Path -LiteralPath $f)) { throw "样式 '$name' 的过滤器不存在: $f" }
    }
    return $conf
}

$styleConfigs = @{}
$allTexInputs = @()
$allEnv = @{}
foreach ($name in $availableStyles) {
    $config = Read-StyleConf $name
    $styleConfigs[$name] = $config
    $allTexInputs += $config.TexInputs
    foreach ($var in $config.Env.Keys) {
        if ($allEnv.ContainsKey($var) -and $allEnv[$var] -ne $config.Env[$var]) {
            Write-Warning "样式环境变量 $var 存在冲突，使用样式 '$name' 的值"
        }
        $allEnv[$var] = $config.Env[$var]
    }
}

# Set TeX/Lua search paths once, outside the loop. A trailing empty kpathsea
# entry keeps the system default search paths appended.
$pathSep = [IO.Path]::PathSeparator
if ($allTexInputs.Count -gt 0) {
    $uniqueDirs = @($allTexInputs | Select-Object -Unique)
    $env:TEXINPUTS = (($uniqueDirs -join $pathSep) + $pathSep + $env:TEXINPUTS)
}
foreach ($var in $allEnv.Keys) {
    [Environment]::SetEnvironmentVariable($var, $allEnv[$var], "Process")
}

# Read only the first Front Matter block. Only an unindented top-level
# `style:` key counts; quotes and trailing inline comments are accepted.
function Get-FrontMatterStyle([string]$path) {
    $lines = @(Get-Content -LiteralPath $path -Encoding UTF8 -TotalCount 200)
    if ($lines.Count -eq 0) { return $defaultStyle }
    $first = $lines[0].TrimStart([char]0xFEFF).TrimEnd("`r")
    if ($first -ne "---") { return $defaultStyle }
    for ($i = 1; $i -lt $lines.Count; $i++) {
        $line = $lines[$i].TrimEnd("`r")
        if ($line -eq "---" -or $line -eq "...") { break }
        if ($line -match '^style\s*:\s*(.*)$') {
            $value = $matches[1].Trim()
            if ($value -match "^[`"`']([^`"`']*)[`"`']") {
                $value = $matches[1]
            } else {
                $value = ($value -split "\s+#", 2)[0].Trim()
            }
            if ($value) { return $value }
        }
    }
    return $defaultStyle
}

$availableList = $availableStyles -join ", "
$failed = $false
Get-ChildItem -Filter "*.md" | ForEach-Object {
    $inputFile = $_.FullName
    $outputFile = Join-Path "../build" ($_.BaseName + ".pdf")
    $style = Get-FrontMatterStyle $inputFile

    if (-not $styleConfigs.ContainsKey($style)) {
        [Console]::Error.WriteLine("错误: 未知的样式 '$style'（文件 $($_.Name)）。可用样式: $availableList")
        $failed = $true
    } else {
        $config = $styleConfigs[$style]
        Write-Host "=> 构建 $($_.Name) - 样式 $style"

        $pandocArgs = @(
            $inputFile,
            "-o", $outputFile,
            "--from", "markdown+alerts",
            "--template", $config.Template,
            "--syntax-highlighting", "idiomatic",
            "--pdf-engine", "lualatex",
            "-V", "CJKmainfont=SimSun",
            "-V", "mainfont=Source Sans 3",
            "-V", "mainfontfallback=Noto Color Emoji:mode=harf",
            "-V", "mainfontfallback=FreeSans:mode=harf",
            "-V", "mainfontfallback=DejaVu Sans:mode=harf",
            "--lua-filter", "../resources/alerts.lua",
            "--lua-filter", "../resources/diagram.lua"
        )
        foreach ($filter in $config.Filters) {
            $pandocArgs += @("--lua-filter", $filter)
        }
        foreach ($arg in $config.ExtraArgs) { $pandocArgs += $arg }

        & pandoc @pandocArgs
        if ($LASTEXITCODE -ne 0) {
            Write-Host "   失败: $($_.Name)" -ForegroundColor Red
            $failed = $true
        } else {
            Write-Host "   成功"
        }
    }
}

if ($failed) {
    [Console]::Error.WriteLine("部分文件构建失败")
    exit 1
}
