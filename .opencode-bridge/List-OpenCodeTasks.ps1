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
        [pscustomobject][ordered]@{
            taskId = $status.taskId
            state = $status.state
            mode = $status.mode
            model = if ($status.model) { $status.model } else { $config.defaultModel }
            sessionId = $status.sessionId
            webUrl = if ($status.sessionId) { Get-OpenCodeSessionWebUrl -ServerUrl ([string]$config.serverUrl) -Directory ([string]$status.workdir) -SessionId ([string]$status.sessionId) } else { $null }
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
