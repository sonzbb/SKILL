param(
    [Parameter(Mandatory)][string]$TaskId,
    [string]$TaskRoot,
    [switch]$Json
)

. (Join-Path $PSScriptRoot 'Common.ps1')
$directory = Get-TaskDirectory $TaskRoot $TaskId
$status = Read-TaskStatus $directory
$config = Get-BridgeConfig
$monitor = Get-OpenCodeTaskMonitorInfo -TaskDirectory $directory -Status $status
$result = [ordered]@{
    taskId = $status.taskId
    state = $status.state
    mode = $status.mode
    model = if ($status.model) { $status.model } else { $config.defaultModel }
    passEnv = @($status.passEnv)
    sessionId = $status.sessionId
    webUrl = $monitor.monitorUrl
    monitorUrl = $monitor.monitorUrl
    monitorPath = $monitor.monitorPath
    monitorHtmlPath = $monitor.monitorHtmlPath
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
