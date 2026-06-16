param(
    [Parameter(Mandatory)][string]$TaskId,
    [string]$TaskRoot,
    [string]$MessagesFile,
    [string]$ServerUrl
)

. (Join-Path $PSScriptRoot 'Common.ps1')
$directory = Get-TaskDirectory $TaskRoot $TaskId
$status = Read-TaskStatus $directory
$log = Get-ChildItem -LiteralPath $directory -Filter 'invocation-*.jsonl' -File |
    Sort-Object LastWriteTime -Descending |
    Select-Object -First 1
if (-not $log) { throw 'No invocation log is available for recovery.' }

$parsed = Get-OpenCodeResult (Get-Content -LiteralPath $log.FullName)
if (-not $parsed.sessionId) { throw 'No session ID was found in the invocation log.' }

if ($MessagesFile) {
    $messages = Get-Content -LiteralPath $MessagesFile -Raw | ConvertFrom-Json
} else {
    if (-not $ServerUrl) { $ServerUrl = [string](Get-BridgeConfig).serverUrl }
    if (-not (Test-OpenCodeServer $ServerUrl)) { throw "OpenCode Server is unavailable: $ServerUrl" }
    $messages = Get-Utf8Json ($ServerUrl.TrimEnd('/') + '/session/' + $parsed.sessionId + '/message')
}

$text = Get-FinalTextFromMessages $messages
if ([string]::IsNullOrWhiteSpace($text)) { throw 'The session has no final assistant text.' }

$sessionPath = Join-Path $directory 'session.json'
$resultPath = Join-Path $directory 'result.md'
$messages | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath $sessionPath -Encoding utf8
$text | Set-Content -LiteralPath $resultPath -Encoding utf8
$status.sessionId = $parsed.sessionId
$status.state = 'idle'
$status.finishedAt = (Get-Date).ToString('o')
$status.lastExitCode = 0
$status.lastLogPath = $log.FullName
$status.resultPath = $resultPath
Write-TaskStatus $directory $status
Write-Output $resultPath
