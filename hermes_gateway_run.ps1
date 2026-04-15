# ============================================================================
# Hermes Gateway 启动器
# ============================================================================
# 功能：
#   - 后台运行 hermes gateway run -vv（默认）
#   - stdout / stderr 合并写入按日期命名的日志文件
#   - 启动时自动清理超过保留天数的旧日志
#   - 支持 -Stop / -Status 管理已启动的进程
#
# 用法：
#   .\hermes_gateway_run.ps1                   # 后台启动
#   .\hermes_gateway_run.ps1 -Foreground       # 前台运行（调试用）
#   .\hermes_gateway_run.ps1 -Stop             # 停止后台进程
#   .\hermes_gateway_run.ps1 -Status           # 查看运行状态
#   .\hermes_gateway_run.ps1 -LogRetentionDays 14  # 保留 14 天日志
# ============================================================================

param(
    [string]$LogDir          = "$env:LOCALAPPDATA\hermes\logs",
    [int]   $LogRetentionDays = 7,
    [switch]$Foreground,
    [switch]$Stop,
    [switch]$Status
)

$ErrorActionPreference = "Stop"

$PidFile    = Join-Path $LogDir "hermes-gateway.pid"
$LogPattern = "hermes-gateway-*.log"

# ── 辅助函数 ─────────────────────────────────────────────────────────────────

function Write-Info    { param($m) Write-Host "→ $m" -ForegroundColor Cyan    }
function Write-Ok      { param($m) Write-Host "✓ $m" -ForegroundColor Green   }
function Write-Warn    { param($m) Write-Host "⚠ $m" -ForegroundColor Yellow  }
function Write-Failure { param($m) Write-Host "✗ $m" -ForegroundColor Red     }

function Get-SavedPid {
    if (Test-Path $PidFile) {
        $raw = Get-Content $PidFile -Raw
        $savedPid = [int]($raw.Trim())
        return $savedPid
    }
    return $null
}

function Get-GatewayProcess {
    $savedPid = Get-SavedPid
    if ($null -eq $savedPid) { return $null }
    try {
        $proc = Get-Process -Id $savedPid -ErrorAction SilentlyContinue
        return $proc
    } catch { return $null }
}

# ── -Status ──────────────────────────────────────────────────────────────────

if ($Status) {
    $proc = Get-GatewayProcess
    if ($proc) {
        $uptime = [math]::Round(((Get-Date) - $proc.StartTime).TotalMinutes, 1)
        Write-Ok "hermes gateway 正在运行  PID=$($proc.Id)  已运行 $uptime 分钟"
    } else {
        Write-Warn "hermes gateway 未运行（未找到 PID 文件或进程已退出）"
    }
    exit 0
}

# ── -Stop ─────────────────────────────────────────────────────────────────────

if ($Stop) {
    $proc = Get-GatewayProcess
    if ($proc) {
        Write-Info "正在停止 PID=$($proc.Id) ..."
        Stop-Process -Id $proc.Id -Force
        Remove-Item $PidFile -Force -ErrorAction SilentlyContinue
        Write-Ok "已停止"
    } else {
        Write-Warn "未找到正在运行的 hermes gateway 进程"
    }
    exit 0
}

# ── 准备日志目录 ──────────────────────────────────────────────────────────────

if (-not (Test-Path $LogDir)) {
    New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
}

# ── 清理过期日志 ──────────────────────────────────────────────────────────────

$cutoff = (Get-Date).AddDays(-$LogRetentionDays)
Get-ChildItem -Path $LogDir -Filter $LogPattern -ErrorAction SilentlyContinue |
    Where-Object { $_.LastWriteTime -lt $cutoff } |
    ForEach-Object {
        Remove-Item $_.FullName -Force
        Write-Host "  已删除过期日志: $($_.Name)" -ForegroundColor DarkGray
    }

# ── 当前日志文件（按日期命名）────────────────────────────────────────────────

$today   = Get-Date -Format "yyyy-MM-dd"
$LogFile = Join-Path $LogDir "hermes-gateway-$today.log"

# ── 检查是否已有实例在运行 ────────────────────────────────────────────────────

$existing = Get-GatewayProcess
if ($existing) {
    Write-Warn "hermes gateway 已在运行（PID=$($existing.Id)）。若需重启请先执行 -Stop。"
    exit 1
}

# ── 前台模式 ──────────────────────────────────────────────────────────────────

if ($Foreground) {
    Write-Info "前台模式启动，日志同时写入: $LogFile"
    Write-Info "按 Ctrl+C 退出"
    Write-Host ""
    # 强制 Python 及 PowerShell 管道均使用 UTF-8，避免 GBK 编码错误
    $env:PYTHONIOENCODING     = "utf-8"
    $env:PYTHONUTF8           = "1"
    [Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)
    $OutputEncoding           = [System.Text.UTF8Encoding]::new($false)
    & hermes gateway run -vv 2>&1 | Tee-Object -FilePath $LogFile -Append
    exit $LASTEXITCODE
}

# ── 后台模式 ──────────────────────────────────────────────────────────────────
#
# 使用 Start-Process 启动隐藏的 powershell.exe 子进程，将 hermes 的
# stdout+stderr 合并后追加写入日志文件，进程与当前会话完全解耦。

$innerCmd = @"
`$env:PYTHONIOENCODING     = 'utf-8'
`$env:PYTHONUTF8           = '1'
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new(`$false)
`$OutputEncoding           = [System.Text.UTF8Encoding]::new(`$false)
`$LogFile = '$($LogFile -replace "'","''")'
`$enc = [System.Text.UTF8Encoding]::new(`$false)
`$writer = [System.IO.StreamWriter]::new(`$LogFile, `$true, `$enc)
`$writer.AutoFlush = `$true
try {
    & hermes gateway run -vv 2>&1 | ForEach-Object {
        `$line = "`$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')  `$_"
        `$writer.WriteLine(`$line)
    }
} finally {
    `$writer.Close()
}
"@

$encoded = [Convert]::ToBase64String([System.Text.Encoding]::Unicode.GetBytes($innerCmd))

$proc = Start-Process powershell.exe `
    -ArgumentList "-NoProfile", "-NonInteractive", "-EncodedCommand", $encoded `
    -WindowStyle Hidden `
    -PassThru

$proc.Id | Set-Content -Path $PidFile -Encoding UTF8

Write-Ok "hermes gateway 已在后台启动"
Write-Host "  PID      : $($proc.Id)" -ForegroundColor DarkGray
Write-Host "  日志文件 : $LogFile"     -ForegroundColor DarkGray
Write-Host "  PID 文件 : $PidFile"     -ForegroundColor DarkGray
Write-Host ""
Write-Host "  查看日志 : Get-Content '$LogFile' -Wait" -ForegroundColor DarkGray
Write-Host "  停止服务 : .\hermes_gateway_run.ps1 -Stop" -ForegroundColor DarkGray
