param(
    [Parameter(Mandatory)][string]$TaskId,
    [Parameter(Mandatory)][string]$FollowUpFile,
    [string]$TaskRoot,
    [string]$OpenCodePath = 'opencode',
    [switch]$AuthorizeWrite,
    [switch]$NoServer
)

. (Join-Path $PSScriptRoot 'Common.ps1')
$directory = Get-TaskDirectory $TaskRoot $TaskId
$status = Read-TaskStatus $directory
if ($status.state -ne 'idle') { throw "Task must be idle before resume; current state: $($status.state)" }
if (-not $status.sessionId) { throw 'No OpenCode session ID is recorded.' }
if (-not (Test-Path -LiteralPath $FollowUpFile -PathType Leaf)) { throw "Follow-up file not found: $FollowUpFile" }
if ($status.mode -eq 'repo-write' -and -not $AuthorizeWrite) { throw 'repo-write resume requires -AuthorizeWrite for this invocation.' }

$status.state = 'running'
$status.startedAt = (Get-Date).ToString('o')
Write-TaskStatus $directory $status

try {
    $result = Invoke-OpenCodeWorker -TaskDirectory $directory -Status $status -InstructionFile ([System.IO.Path]::GetFullPath($FollowUpFile)) -OpenCodePath $OpenCodePath -SessionId $status.sessionId -NoServer:$NoServer
    if ($result.exitCode -ne 0) { throw "OpenCode exited with code $($result.exitCode)." }
    if ($result.sessionId -ne $status.sessionId) { throw 'OpenCode resume returned a different session ID.' }
    if ([string]::IsNullOrWhiteSpace($result.text)) { throw 'OpenCode returned no final Markdown result.' }

    $resultPath = Join-Path $directory 'result.md'
    $result.text | Set-Content -LiteralPath $resultPath -Encoding utf8
    $status.state = 'idle'
    $status.finishedAt = (Get-Date).ToString('o')
    $status.lastExitCode = 0
    $status.lastLogPath = $result.logPath
    $status.resultPath = $resultPath
    Write-TaskStatus $directory $status
    Write-Output $resultPath
} catch {
    $status.state = 'failed'
    $status.finishedAt = (Get-Date).ToString('o')
    $status.lastExitCode = if ($result) { $result.exitCode } else { -1 }
    if ($result) { $status.lastLogPath = $result.logPath }
    Write-TaskStatus $directory $status
    throw
}
