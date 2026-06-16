param(
    [Parameter(Mandatory)][string]$TaskId,
    [string]$TaskRoot,
    [string]$OpenCodePath = 'opencode',
    [switch]$AuthorizeWrite,
    [switch]$Retry,
    [switch]$PreparedSession,
    [switch]$NoServer
)

. (Join-Path $PSScriptRoot 'Common.ps1')
$directory = Get-TaskDirectory $TaskRoot $TaskId
$status = Read-TaskStatus $directory
if ($status.state -eq 'running') { throw "Task is already active: $TaskId" }
if ($status.state -eq 'failed' -and -not $Retry) { throw 'Failed tasks require -Retry.' }
if ($status.sessionId -and -not $PreparedSession) { throw 'Task already has a session. Use Resume-OpenCodeTask.ps1.' }
if ($PreparedSession -and -not $status.sessionId) { throw 'Prepared session mode requires a recorded session ID.' }
if ($status.externalDisclosureApproval -ne 'yes') { throw 'External disclosure approval must be yes.' }
if ($status.mode -eq 'repo-write' -and -not $AuthorizeWrite) { throw 'repo-write requires -AuthorizeWrite for this invocation.' }

$taskPath = Join-Path $directory 'task.md'
$status.state = 'running'
$status.startedAt = (Get-Date).ToString('o')
Write-TaskStatus $directory $status

try {
    $result = Invoke-OpenCodeWorker -TaskDirectory $directory -Status $status -InstructionFile $taskPath -OpenCodePath $OpenCodePath -SessionId $(if ($PreparedSession) { [string]$status.sessionId } else { $null }) -NoServer:$NoServer
    if ($result.exitCode -ne 0) { throw "OpenCode exited with code $($result.exitCode)." }
    if ([string]::IsNullOrWhiteSpace($result.sessionId)) { throw 'OpenCode returned no session ID.' }
    if ($PreparedSession -and $result.sessionId -ne $status.sessionId) { throw 'OpenCode returned a different prepared session ID.' }
    if ([string]::IsNullOrWhiteSpace($result.text)) { throw 'OpenCode returned no final Markdown result.' }

    $resultPath = Join-Path $directory 'result.md'
    $result.text | Set-Content -LiteralPath $resultPath -Encoding utf8
    $status.sessionId = $result.sessionId
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
