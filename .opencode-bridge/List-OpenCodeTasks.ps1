param(
    [string]$TaskRoot,
    [ValidateSet('draft', 'queued', 'running', 'idle', 'failed')][string]$State,
    [switch]$Json
)

. (Join-Path $PSScriptRoot 'Common.ps1')
$root = Resolve-TaskRoot $TaskRoot
$config = Get-BridgeConfig
if (-not (Test-Path -LiteralPath $root -PathType Container)) {
    $tasks = @()
} else {
    $tasks = @(Get-ChildItem -LiteralPath $root -Directory | ForEach-Object {
        $statusPath = Join-Path $_.FullName 'status.json'
        if (-not (Test-Path -LiteralPath $statusPath -PathType Leaf)) { return }
        try {
            $status = Get-Content -LiteralPath $statusPath -Raw | ConvertFrom-Json
        } catch {
            Write-Warning "Skipping invalid task status: $statusPath"
            return
        }
        if ($State -and $status.state -ne $State) { return }
        $monitor = Get-OpenCodeTaskMonitorInfo -TaskDirectory $_.FullName -Status $status
        [pscustomobject][ordered]@{
            taskId = $status.taskId
            state = $status.state
            mode = $status.mode
            model = if ($status.model) { $status.model } else { $config.defaultModel }
            sessionId = $status.sessionId
            webUrl = $monitor.monitorUrl
            monitorUrl = $monitor.monitorUrl
            monitorPath = $monitor.monitorPath
            monitorHtmlPath = $monitor.monitorHtmlPath
            createdAt = $status.createdAt
            finishedAt = $status.finishedAt
            resultPath = $status.resultPath
        }
    } | Sort-Object createdAt -Descending)
}

if ($Json) {
    ConvertTo-Json -InputObject @($tasks) -Depth 5
} else {
    $tasks
}
