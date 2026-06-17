param(
    [switch]$Desktop,
    [switch]$Tui,
    [switch]$Web,
    [string]$Project = (Get-Location).Path,
    [string]$OpenCodePath = 'opencode'
)

. (Join-Path $PSScriptRoot 'Common.ps1')
$config = Get-BridgeConfig
if (-not ($Desktop -or $Tui -or $Web)) { $Web = $true }

$resolvedCommand = Get-Command $OpenCodePath -ErrorAction Stop
$resolvedOpenCode = $resolvedCommand.Source
if (-not $resolvedOpenCode) { $resolvedOpenCode = $resolvedCommand.Definition }

function Start-OpenCodeCliProcess {
    param([string[]]$Arguments, [switch]$Visible)
    $windowStyle = if ($Visible) { 'Normal' } else { 'Hidden' }
    if ([System.IO.Path]::GetExtension($resolvedOpenCode) -eq '.ps1') {
        return Start-Process -FilePath 'powershell.exe' -ArgumentList (@('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $resolvedOpenCode) + $Arguments) -WorkingDirectory $Project -WindowStyle $windowStyle -PassThru
    }
    return Start-Process -FilePath $resolvedOpenCode -ArgumentList $Arguments -WorkingDirectory $Project -WindowStyle $windowStyle -PassThru
}

if ($Web -and -not (Test-OpenCodeServer ([string]$config.serverUrl))) {
    $webArgs = @('web', '--hostname', [string]$config.serverHost, '--port', [string]$config.serverPort)
    $previousRuntimeEnv = Set-OpenCodeRuntimeEnvironment
    try {
        Start-OpenCodeCliProcess -Arguments $webArgs | Out-Null
    } finally {
        Restore-OpenCodeRuntimeEnvironment $previousRuntimeEnv
    }
    $ready = $false
    foreach ($attempt in 1..40) {
        Start-Sleep -Milliseconds 250
        if (Test-OpenCodeServer ([string]$config.serverUrl)) { $ready = $true; break }
    }
    if (-not $ready) { throw "OpenCode Web did not become healthy at $($config.serverUrl)" }
}

if ($Desktop) {
    $candidates = @(
        "$env:LOCALAPPDATA\Programs\@opencode-aidesktop\OpenCode.exe",
        "$env:LOCALAPPDATA\Programs\OpenCode\OpenCode.exe"
    )
    $desktopPath = $candidates | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
    if (-not $desktopPath) { throw 'OpenCode desktop executable was not found.' }
    Start-Process -FilePath $desktopPath -WorkingDirectory $Project | Out-Null
}

if ($Tui) {
    Start-Process -FilePath 'powershell.exe' -ArgumentList @('-NoExit', '-Command', "& '$OpenCodePath' attach '$($config.serverUrl)' --dir '$Project'") -WorkingDirectory $Project | Out-Null
}

Write-Output ([pscustomobject]@{ serverUrl = $config.serverUrl; desktop = [bool]$Desktop; tui = [bool]$Tui; web = [bool]$Web })
