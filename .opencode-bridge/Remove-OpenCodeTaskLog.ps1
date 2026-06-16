param(
    [Parameter(Mandatory)][string]$TaskId,
    [Parameter(Mandatory)][string]$FileName,
    [string]$TaskRoot
)

. (Join-Path $PSScriptRoot 'Common.ps1')
$directory = Get-TaskDirectory $TaskRoot $TaskId
$status = Read-TaskStatus $directory
if ($status.state -in @('queued', 'running')) {
    throw "Cannot remove a log while task is active: $TaskId"
}
if ($FileName -ne [System.IO.Path]::GetFileName($FileName)) {
    throw 'FileName must be one explicit file name, not a path.'
}
if ($FileName -notin @('background.stdout.log', 'background.stderr.log') -and $FileName -notlike 'invocation-*.jsonl') {
    throw "File is not an approved disposable log: $FileName"
}

$path = Join-Path $directory $FileName
if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
    throw "Log file not found: $path"
}
Remove-Item -LiteralPath $path
Write-Output $path

