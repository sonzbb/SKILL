param(
    [Parameter(Mandatory)][string]$TaskId,
    [Parameter(Mandatory)][string]$TaskRoot,
    [string]$OpenCodePath = 'opencode',
    [switch]$AuthorizeWrite,
    [switch]$Retry,
    [switch]$PreparedSession,
    [switch]$NoServer
)

$directory = Join-Path $TaskRoot $TaskId
$stdoutPath = Join-Path $directory 'background.stdout.log'
$stderrPath = Join-Path $directory 'background.stderr.log'
'' | Set-Content -LiteralPath $stdoutPath -Encoding utf8
'' | Set-Content -LiteralPath $stderrPath -Encoding utf8

$invokeArguments = @{
    TaskId = $TaskId
    TaskRoot = $TaskRoot
    OpenCodePath = $OpenCodePath
}
if ($AuthorizeWrite) { $invokeArguments.AuthorizeWrite = $true }
if ($Retry) { $invokeArguments.Retry = $true }
if ($PreparedSession) { $invokeArguments.PreparedSession = $true }
if ($NoServer) { $invokeArguments.NoServer = $true }

try {
    & (Join-Path $PSScriptRoot 'Invoke-OpenCodeTask.ps1') @invokeArguments 2>&1 |
        Set-Content -LiteralPath $stdoutPath -Encoding utf8
} catch {
    ($_ | Out-String) | Set-Content -LiteralPath $stderrPath -Encoding utf8
    exit 1
}
