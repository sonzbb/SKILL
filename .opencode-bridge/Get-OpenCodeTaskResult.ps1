param(
    [Parameter(Mandatory)][string]$TaskId,
    [string]$TaskRoot,
    [switch]$Json
)

. (Join-Path $PSScriptRoot 'Common.ps1')
$directory = Get-TaskDirectory $TaskRoot $TaskId
$status = Read-TaskStatus $directory
$config = Get-BridgeConfig
$result = [ordered]@{
    taskId = $status.taskId
    state = $status.state
    mode = $status.mode
    model = if ($status.model) { $status.model } else { $config.defaultModel }
    passEnv = @($status.passEnv)
    sessionId = $status.sessionId
    webUrl = if ($status.sessionId) { Get-OpenCodeSessionWebUrl -ServerUrl ([string]$config.serverUrl) -Directory ([string]$status.workdir) -SessionId ([string]$status.sessionId) } else { $null }
    monitorProcessId = $status.monitorProcessId
    monitorType = $status.monitorType
    startedAt = $status.startedAt
    finishedAt = $status.finishedAt
    resultPath = $status.resultPath
    logPath = $status.lastLogPath
}
if ($Json) {
    $result | ConvertTo-Json -Depth 5
} else {
    $result.GetEnumerator() | ForEach-Object { '{0}: {1}' -f $_.Key, $_.Value }
    if ($status.resultPath -and (Test-Path -LiteralPath $status.resultPath)) {
        Write-Output ''
        Get-Content -LiteralPath $status.resultPath -Raw
    }
}
