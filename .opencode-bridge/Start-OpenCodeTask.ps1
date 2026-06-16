param(
    [Parameter(Mandatory)][string]$TaskId,
    [string]$TaskRoot,
    [string]$OpenCodePath = 'opencode',
    [switch]$AuthorizeWrite,
    [switch]$Retry,
    [switch]$NoMonitor,
    [switch]$NoServer,
    [switch]$Wait,
    [ValidateRange(0, 86400)][int]$WaitTimeoutSeconds = 0,
    [ValidateRange(0, 60000)][int]$WaitPollIntervalMilliseconds = 0
)

. (Join-Path $PSScriptRoot 'Common.ps1')
$directory = Get-TaskDirectory $TaskRoot $TaskId
$status = Read-TaskStatus $directory
if ($status.state -notin @('draft', 'failed')) { throw "Task cannot be started from state: $($status.state)" }
if ($status.mode -eq 'repo-write' -and -not $AuthorizeWrite) { throw 'repo-write requires -AuthorizeWrite for this invocation.' }
if ($status.PSObject.Properties.Name -notcontains 'webUrl') { $status | Add-Member -NotePropertyName webUrl -NotePropertyValue $null }
if ($status.PSObject.Properties.Name -notcontains 'monitorProcessId') { $status | Add-Member -NotePropertyName monitorProcessId -NotePropertyValue $null }
if ($status.PSObject.Properties.Name -notcontains 'monitorType') { $status | Add-Member -NotePropertyName monitorType -NotePropertyValue $null }

$config = Get-BridgeConfig
if (-not $NoServer -and -not (Test-OpenCodeServer ([string]$config.serverUrl))) {
    & (Join-Path $PSScriptRoot 'Open-OpenCode.ps1') -Web -Project ([string]$status.workdir) -OpenCodePath $OpenCodePath | Out-Null
    if (-not (Test-OpenCodeServer ([string]$config.serverUrl))) {
        throw "OpenCode Web did not become healthy at $($config.serverUrl)"
    }
}
$preparedSession = $false
if (-not $NoServer -and (Test-OpenCodeServer ([string]$config.serverUrl))) {
    if (-not $status.sessionId) {
        $session = New-OpenCodeServerSession -ServerUrl ([string]$config.serverUrl) -Directory ([string]$status.workdir) -Title ("Sidecar: " + $TaskId) -Agent ([string]$status.mode) -Model ([string]$status.model)
        $status.sessionId = [string]$session.id
    }
    $status.webUrl = Get-OpenCodeSessionWebUrl -ServerUrl ([string]$config.serverUrl) -Directory ([string]$status.workdir) -SessionId ([string]$status.sessionId)
    if (-not $NoMonitor) {
        $monitor = Start-OpenCodeSessionMonitor -ServerUrl ([string]$config.serverUrl) -Directory ([string]$status.workdir) -SessionId ([string]$status.sessionId) -OpenCodePath $OpenCodePath
        $status.monitorProcessId = $monitor.processId
        $status.monitorType = $monitor.type
    }
    $preparedSession = $true
}

$arguments = @(
    '-NoProfile', '-ExecutionPolicy', 'Bypass',
    '-File', (Join-Path $PSScriptRoot 'Run-OpenCodeTaskBackground.ps1'),
    '-TaskId', $TaskId,
    '-TaskRoot', (Resolve-TaskRoot $TaskRoot),
    '-OpenCodePath', $OpenCodePath
)
if ($AuthorizeWrite) { $arguments += '-AuthorizeWrite' }
if ($Retry) { $arguments += '-Retry' }
if ($preparedSession) { $arguments += '-PreparedSession' }
if ($NoServer) { $arguments += '-NoServer' }

$status.state = 'queued'
Write-TaskStatus $directory $status
$process = Start-Process -FilePath 'powershell.exe' -ArgumentList $arguments -WindowStyle Hidden -PassThru
$queuedResult = [pscustomobject]@{
    taskId = $TaskId
    state = 'queued'
    processId = $process.Id
    sessionId = $status.sessionId
    webUrl = $status.webUrl
    monitorProcessId = $status.monitorProcessId
    monitorType = $status.monitorType
}
if ($Wait) {
    & (Join-Path $PSScriptRoot 'Wait-OpenCodeTask.ps1') -TaskId $TaskId -TaskRoot (Resolve-TaskRoot $TaskRoot) -TimeoutSeconds $WaitTimeoutSeconds -PollIntervalMilliseconds $WaitPollIntervalMilliseconds
} else {
    Write-Output $queuedResult
}
