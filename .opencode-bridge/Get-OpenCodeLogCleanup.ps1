param(
    [Parameter(Mandatory)][string]$TaskId,
    [ValidateRange(0, 3650)][int]$OlderThanDays = 30,
    [string]$TaskRoot
)

. (Join-Path $PSScriptRoot 'Common.ps1')
$directory = Get-TaskDirectory $TaskRoot $TaskId
$status = Read-TaskStatus $directory
if ($status.state -in @('queued', 'running')) {
    throw "Cannot inspect cleanup candidates while task is active: $TaskId"
}

$cutoff = (Get-Date).AddDays(-$OlderThanDays)
$allowedNames = @('background.stdout.log', 'background.stderr.log')
Get-ChildItem -LiteralPath $directory -File | Where-Object {
    ($allowedNames -contains $_.Name -or $_.Name -like 'invocation-*.jsonl') -and $_.LastWriteTime -lt $cutoff
} | Sort-Object LastWriteTime | ForEach-Object {
    [pscustomobject][ordered]@{
        taskId = $TaskId
        fileName = $_.Name
        fullPath = $_.FullName
        sizeBytes = $_.Length
        lastWriteTime = $_.LastWriteTime.ToString('o')
    }
}

