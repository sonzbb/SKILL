$ErrorActionPreference = 'Stop'

function Assert-TaskId {
    param([Parameter(Mandatory)][string]$TaskId)
    if ($TaskId -notmatch '^[A-Za-z0-9][A-Za-z0-9._-]*$') {
        throw "Invalid task ID: $TaskId"
    }
}

function Resolve-TaskRoot {
    param([string]$TaskRoot)
    if ($TaskRoot) {
        return [System.IO.Path]::GetFullPath($TaskRoot)
    }
    return [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\.opencode-tasks'))
}

function Get-TaskDirectory {
    param([string]$TaskRoot, [string]$TaskId)
    Assert-TaskId $TaskId
    return Join-Path (Resolve-TaskRoot $TaskRoot) $TaskId
}

function Read-TaskStatus {
    param([string]$TaskDirectory)
    $path = Join-Path $TaskDirectory 'status.json'
    if (-not (Test-Path -LiteralPath $path)) {
        throw "Task status not found: $path"
    }
    return Get-Content -LiteralPath $path -Raw | ConvertFrom-Json
}

function Write-TaskStatus {
    param([string]$TaskDirectory, [object]$Status)
    $path = Join-Path $TaskDirectory 'status.json'
    $temp = "$path.tmp"
    $Status | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $temp -Encoding utf8
    Move-Item -LiteralPath $temp -Destination $path -Force
    Update-OpenCodeTaskMonitorArtifacts -TaskDirectory $TaskDirectory -Status $Status
}

function Get-BridgeConfig {
    $path = Join-Path $PSScriptRoot 'config.json'
    return Get-Content -LiteralPath $path -Raw | ConvertFrom-Json
}

function ConvertTo-OpenCodeDirectoryToken {
    param([Parameter(Mandatory)][string]$Directory)
    $bytes = [System.Text.Encoding]::UTF8.GetBytes([System.IO.Path]::GetFullPath($Directory))
    return [Convert]::ToBase64String($bytes).TrimEnd('=').Replace('+', '-').Replace('/', '_')
}

function Get-OpenCodeSessionWebUrl {
    param(
        [Parameter(Mandatory)][string]$ServerUrl,
        [Parameter(Mandatory)][string]$Directory,
        [Parameter(Mandatory)][string]$SessionId
    )
    $directoryToken = ConvertTo-OpenCodeDirectoryToken $Directory
    return $ServerUrl.TrimEnd('/') + '/' + $directoryToken + '/session/' + $SessionId
}

function Get-OpenCodeTaskMonitorMarkdownPath {
    param([Parameter(Mandatory)][string]$TaskDirectory)
    return Join-Path $TaskDirectory 'monitor.md'
}

function Get-OpenCodeTaskMonitorHtmlPath {
    param([Parameter(Mandatory)][string]$TaskDirectory)
    return Join-Path $TaskDirectory 'monitor.html'
}

function Get-OpenCodeTaskMonitorInfo {
    param(
        [Parameter(Mandatory)][string]$TaskDirectory,
        [Parameter(Mandatory)][object]$Status
    )
    $config = Get-BridgeConfig
    $monitorUrl = $null
    if ($Status.sessionId -and $Status.workdir) {
        $monitorUrl = Get-OpenCodeSessionWebUrl -ServerUrl ([string]$config.serverUrl) -Directory ([string]$Status.workdir) -SessionId ([string]$Status.sessionId)
    }
    return [pscustomobject]@{
        monitorUrl = $monitorUrl
        monitorPath = Get-OpenCodeTaskMonitorMarkdownPath -TaskDirectory $TaskDirectory
        monitorHtmlPath = Get-OpenCodeTaskMonitorHtmlPath -TaskDirectory $TaskDirectory
    }
}

function Update-OpenCodeTaskMonitorArtifacts {
    param(
        [Parameter(Mandatory)][string]$TaskDirectory,
        [Parameter(Mandatory)][object]$Status
    )
    $monitor = Get-OpenCodeTaskMonitorInfo -TaskDirectory $TaskDirectory -Status $Status
    $webUrlText = if ($monitor.monitorUrl) { [string]$monitor.monitorUrl } else { 'Pending session URL. Start the task first.' }
    $monitorMd = @"
# OpenCode Task Monitor

- Task ID: $($Status.taskId)
- State: $($Status.state)
- Mode: $($Status.mode)
- Model: $(if ($Status.model) { $Status.model } else { (Get-BridgeConfig).defaultModel })
- Session ID: $(if ($Status.sessionId) { $Status.sessionId } else { 'Pending' })
- Monitor URL: $webUrlText
- Monitor HTML: $($monitor.monitorHtmlPath)

## How To Use

- Open the `Monitor URL` in the Codex in-app browser to watch the live OpenCode session.
- If you prefer a local artifact, open `monitor.html` from this task directory.
- Codex should report this monitor entry whenever a sidecar task is dispatched.
"@
    $monitorMd | Set-Content -LiteralPath $monitor.monitorPath -Encoding utf8

    $encodedTaskId = [System.Net.WebUtility]::HtmlEncode([string]$Status.taskId)
    $encodedState = [System.Net.WebUtility]::HtmlEncode([string]$Status.state)
    $encodedMode = [System.Net.WebUtility]::HtmlEncode([string]$Status.mode)
    $encodedModel = [System.Net.WebUtility]::HtmlEncode([string]$(if ($Status.model) { $Status.model } else { (Get-BridgeConfig).defaultModel }))
    $encodedSessionId = [System.Net.WebUtility]::HtmlEncode([string]$(if ($Status.sessionId) { $Status.sessionId } else { 'Pending' }))
    $encodedMonitorUrl = [System.Net.WebUtility]::HtmlEncode([string]$monitor.monitorUrl)
    $iframeBlock = if ($monitor.monitorUrl) {
@"
<p><a href="$encodedMonitorUrl" target="_blank" rel="noopener noreferrer">Open live session directly</a></p>
<iframe src="$encodedMonitorUrl" title="OpenCode live session"></iframe>
"@
    } else {
@"
<p>Session URL is not available yet. Start the task first, then reopen this page.</p>
"@
    }
    $monitorHtml = @"
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <title>OpenCode Task Monitor - $encodedTaskId</title>
  <style>
    body { font-family: Arial, sans-serif; margin: 16px; color: #111; }
    .meta { margin-bottom: 16px; }
    .meta p { margin: 4px 0; }
    iframe { width: 100%; height: 80vh; border: 1px solid #ccc; border-radius: 8px; }
  </style>
</head>
<body>
  <h1>OpenCode Task Monitor</h1>
  <div class="meta">
    <p><strong>Task ID:</strong> $encodedTaskId</p>
    <p><strong>State:</strong> $encodedState</p>
    <p><strong>Mode:</strong> $encodedMode</p>
    <p><strong>Model:</strong> $encodedModel</p>
    <p><strong>Session ID:</strong> $encodedSessionId</p>
  </div>
  $iframeBlock
</body>
</html>
"@
    $monitorHtml | Set-Content -LiteralPath $monitor.monitorHtmlPath -Encoding utf8
}

function Resolve-OpenCodeTaskModel {
    param([string]$Model)
    $config = Get-BridgeConfig
    $resolved = if ([string]::IsNullOrWhiteSpace($Model)) { [string]$config.defaultModel } else { $Model }
    if (@($config.allowedModels) -notcontains $resolved) {
        throw "Model is not allowed by config.json: $resolved"
    }
    return $resolved
}

function Resolve-OpenCodePassEnvNames {
    param([string[]]$PassEnv)
    $config = Get-BridgeConfig
    $resolved = [System.Collections.Generic.List[string]]::new()
    foreach ($name in @($PassEnv)) {
        if ([string]::IsNullOrWhiteSpace($name)) { continue }
        if ($name -notmatch '^[A-Za-z_][A-Za-z0-9_]*$') {
            throw "Invalid environment variable name: $name"
        }
        if (@($config.allowedPassEnv) -notcontains $name) {
            throw "Environment variable is not allowed by config.json: $name"
        }
        if (-not $resolved.Contains($name)) {
            $resolved.Add($name)
        }
    }
    return $resolved.ToArray()
}

function Test-OpenCodeServer {
    param([string]$ServerUrl)
    if (-not $ServerUrl) { return $false }
    try {
        $health = Invoke-RestMethod -Uri ($ServerUrl.TrimEnd('/') + '/global/health') -TimeoutSec 2
        return [bool]$health.healthy
    } catch {
        return $false
    }
}

function Get-Utf8Json {
    param([Parameter(Mandatory)][string]$Uri)
    $client = New-Object System.Net.WebClient
    try {
        $bytes = $client.DownloadData($Uri)
    } finally {
        $client.Dispose()
    }
    $json = [System.Text.Encoding]::UTF8.GetString($bytes)
    return $json | ConvertFrom-Json
}

function New-OpenCodeServerSession {
    param(
        [Parameter(Mandatory)][string]$ServerUrl,
        [Parameter(Mandatory)][string]$Directory,
        [Parameter(Mandatory)][string]$Title,
        [string]$Agent,
        [string]$Model
    )
    $payload = [ordered]@{
        location = @{ directory = [System.IO.Path]::GetFullPath($Directory) }
    }
    if ($Agent) { $payload.agent = $Agent }
    if ($Model -and $Model.Contains('/')) {
        $modelParts = $Model.Split('/', 2)
        $payload.model = @{ providerID = $modelParts[0]; id = $modelParts[1] }
    }
    $body = [System.Text.Encoding]::UTF8.GetBytes(($payload | ConvertTo-Json -Depth 5))
    $response = Invoke-RestMethod -Method Post -Uri ($ServerUrl.TrimEnd('/') + '/api/session') -ContentType 'application/json; charset=utf-8' -Body $body
    if ($response.data) { return $response.data }
    return $response
}

function Start-OpenCodeSessionMonitor {
    param(
        [Parameter(Mandatory)][string]$ServerUrl,
        [Parameter(Mandatory)][string]$Directory,
        [Parameter(Mandatory)][string]$SessionId,
        [string]$OpenCodePath = 'opencode'
    )
    $webUrl = Get-OpenCodeSessionWebUrl -ServerUrl $ServerUrl -Directory $Directory -SessionId $SessionId
    $process = Start-Process -FilePath $webUrl -PassThru
    return [pscustomobject]@{
        type = 'web'
        url = $webUrl
        processId = if ($process) { $process.Id } else { $null }
    }
}

function Get-OpenCodeResult {
    param([string[]]$Lines)
    $sessionId = $null
    $finalText = $null
    foreach ($line in $Lines) {
        try {
            $event = $line | ConvertFrom-Json -ErrorAction Stop
        } catch {
            continue
        }
        if ($event.sessionID) {
            $sessionId = [string]$event.sessionID
        }
        if ($event.part -and $event.part.sessionID) {
            $sessionId = [string]$event.part.sessionID
        }
        if ($event.type -eq 'text' -and $event.part -and $event.part.type -eq 'text' -and $event.part.text) {
            $finalText = [string]$event.part.text
        }
    }
    return [pscustomobject]@{
        sessionId = $sessionId
        text = $finalText
    }
}

function Get-OpenCodeExportResult {
    param([string[]]$Lines)
    $joined = $Lines -join "`n"
    $start = $joined.IndexOf('{')
    $end = $joined.LastIndexOf('}')
    if ($start -lt 0 -or $end -le $start) { return $null }
    try {
        $export = $joined.Substring($start, $end - $start + 1) | ConvertFrom-Json -ErrorAction Stop
    } catch {
        return $null
    }
    $text = $null
    foreach ($message in $export.messages) {
        if ($message.info.role -ne 'assistant') { continue }
        foreach ($part in $message.parts) {
            if ($part.type -eq 'text' -and $part.text) {
                $text = [string]$part.text
            }
        }
    }
    return [pscustomobject]@{
        text = $text
        json = ($export | ConvertTo-Json -Depth 100)
    }
}

function Get-FinalTextFromMessages {
    param([object[]]$Messages)
    $text = $null
    foreach ($message in $Messages) {
        if ($message.info.role -ne 'assistant') { continue }
        foreach ($part in $message.parts) {
            if ($part.type -eq 'text' -and $part.text) {
                $text = [string]$part.text
            }
        }
    }
    return $text
}

function Invoke-OpenCodeWorker {
    param(
        [Parameter(Mandatory)][string]$TaskDirectory,
        [Parameter(Mandatory)][object]$Status,
        [Parameter(Mandatory)][string]$InstructionFile,
        [Parameter(Mandatory)][string]$OpenCodePath,
        [string]$SessionId,
        [switch]$NoServer
    )

    $config = Get-BridgeConfig
    $model = Resolve-OpenCodeTaskModel ([string]$Status.model)
    $passEnv = Resolve-OpenCodePassEnvNames @($Status.passEnv)
    foreach ($name in $passEnv) {
        if ($null -eq [Environment]::GetEnvironmentVariable($name, 'Process')) {
            throw "Requested environment variable is not set: $name"
        }
    }
    $runDirectory = [string]$Status.workdir
    if (-not (Test-Path -LiteralPath $runDirectory -PathType Container)) {
        throw "Worker directory not found: $runDirectory"
    }

    $arguments = @(
        'run',
        'Execute the attached Markdown task exactly. Return the final report as Markdown.',
        '--agent', [string]$Status.mode,
        '--model', $model,
        '--format', 'json',
        '--file', $InstructionFile,
        '--dir', $runDirectory
    )
    if ($SessionId) {
        $arguments += @('--session', $SessionId)
    }
    if (-not $NoServer -and (Test-OpenCodeServer ([string]$config.serverUrl))) {
        $arguments += @('--attach', [string]$config.serverUrl)
    }

    $oldConfig = $env:OPENCODE_CONFIG
    $oldConfigDir = $env:OPENCODE_CONFIG_DIR
    $env:OPENCODE_CONFIG = Join-Path $PSScriptRoot 'opencode-config\opencode.json'
    $env:OPENCODE_CONFIG_DIR = Join-Path $PSScriptRoot 'opencode-config'
    try {
        Push-Location $runDirectory
        try {
            $raw = @(& $OpenCodePath @arguments 2>&1 | ForEach-Object { [string]$_ })
            $exitCode = $LASTEXITCODE
            if ($null -eq $exitCode) { $exitCode = 0 }
        } finally {
            Pop-Location
        }
    } finally {
        $env:OPENCODE_CONFIG = $oldConfig
        $env:OPENCODE_CONFIG_DIR = $oldConfigDir
    }

    $logPath = Join-Path $TaskDirectory ('invocation-' + (Get-Date -Format 'yyyyMMdd-HHmmss') + '.jsonl')
    $raw | Set-Content -LiteralPath $logPath -Encoding utf8
    $parsed = Get-OpenCodeResult $raw
    $sessionExportPath = $null
    if ($parsed.sessionId -and [string]::IsNullOrWhiteSpace($parsed.text) -and -not $NoServer -and (Test-OpenCodeServer ([string]$config.serverUrl))) {
        foreach ($attempt in 1..40) {
            try {
                $messages = Get-Utf8Json (([string]$config.serverUrl).TrimEnd('/') + '/session/' + $parsed.sessionId + '/message')
                $serverText = Get-FinalTextFromMessages $messages
                if ($messages) {
                    $sessionExportPath = Join-Path $TaskDirectory 'session.json'
                    $messages | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath $sessionExportPath -Encoding utf8
                }
                if (-not [string]::IsNullOrWhiteSpace($serverText)) {
                    $parsed.text = $serverText
                    break
                }
            } catch {
                # The session may still be settling; retry briefly before CLI export fallback.
            }
            Start-Sleep -Milliseconds 500
        }
    }
    if ($parsed.sessionId) {
        foreach ($attempt in 1..40) {
            Push-Location $runDirectory
            $oldErrorActionPreference = $ErrorActionPreference
            try {
                $ErrorActionPreference = 'Continue'
                $exportRaw = @(& $OpenCodePath export $parsed.sessionId 2>$null | ForEach-Object { [string]$_ })
            } finally {
                $ErrorActionPreference = $oldErrorActionPreference
                Pop-Location
            }
            $exportResult = Get-OpenCodeExportResult $exportRaw
            if ($exportResult -and $exportResult.json) {
                $sessionExportPath = Join-Path $TaskDirectory 'session.json'
                $exportResult.json | Set-Content -LiteralPath $sessionExportPath -Encoding utf8
            }
            if ([string]::IsNullOrWhiteSpace($parsed.text) -and $exportResult -and -not [string]::IsNullOrWhiteSpace($exportResult.text)) {
                $parsed.text = $exportResult.text
            }
            if (-not [string]::IsNullOrWhiteSpace($parsed.text)) { break }
            Start-Sleep -Milliseconds 500
        }
    }
    return [pscustomobject]@{
        exitCode = $exitCode
        sessionId = $parsed.sessionId
        text = $parsed.text
        logPath = $logPath
        sessionExportPath = $sessionExportPath
        arguments = $arguments
    }
}
