param(
    [Parameter(Mandatory)][string]$TaskId,
    [string]$TaskRoot,
    [ValidateRange(0, 86400)][int]$TimeoutSeconds = 0,
    [ValidateRange(0, 60000)][int]$PollIntervalMilliseconds = 0,
    [switch]$Json
)

. (Join-Path $PSScriptRoot 'Common.ps1')
$directory = Get-TaskDirectory $TaskRoot $TaskId
$config = Get-BridgeConfig
if ($TimeoutSeconds -eq 0) { $TimeoutSeconds = [int]$config.defaultTimeoutSeconds }
if ($PollIntervalMilliseconds -eq 0) { $PollIntervalMilliseconds = [int]$config.waitPollIntervalMilliseconds }

$stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
while ($true) {
    $status = Read-TaskStatus $directory
    if ($status.state -eq 'draft') {
        throw "Task has not been started: $TaskId"
    }
    if ($status.state -notin @('queued', 'running', 'idle', 'failed')) {
        throw "Unknown task state: $($status.state)"
    }
    if ($status.state -in @('idle', 'failed')) {
        $resultText = $null
        if ($status.resultPath -and (Test-Path -LiteralPath $status.resultPath -PathType Leaf)) {
            $resultText = (Get-Content -LiteralPath $status.resultPath -Raw).TrimEnd([char[]]"`r`n")
        }
        $monitor = Get-OpenCodeTaskMonitorInfo -TaskDirectory $directory -Status $status
        $result = [pscustomobject][ordered]@{
            bridgeVersion = if ($status.bridgeVersion) { $status.bridgeVersion } else { $config.bridgeVersion }
            taskId = $status.taskId
            state = $status.state
            mode = $status.mode
            model = if ($status.model) { $status.model } else { $config.defaultModel }
            sessionId = $status.sessionId
            webUrl = $monitor.monitorUrl
            monitorUrl = $monitor.monitorUrl
            monitorPath = $monitor.monitorPath
            monitorHtmlPath = $monitor.monitorHtmlPath
            finishedAt = $status.finishedAt
            resultPath = $status.resultPath
            logPath = $status.lastLogPath
            result = $resultText
        }
        if ($Json) {
            $result | ConvertTo-Json -Depth 5
        } else {
            Write-Output $result
        }
        return
    }
    if ($stopwatch.Elapsed.TotalSeconds -ge $TimeoutSeconds) {
        throw "Timed out waiting for task '$TaskId' after $TimeoutSeconds seconds. Last state: $($status.state)"
    }
    Start-Sleep -Milliseconds $PollIntervalMilliseconds
}
