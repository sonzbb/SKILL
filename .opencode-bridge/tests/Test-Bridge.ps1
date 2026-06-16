param(
    [switch]$SchemaOnly
)

$ErrorActionPreference = 'Stop'
$bridgeRoot = Split-Path -Parent (Split-Path -Parent $PSCommandPath)
$workspaceRoot = Split-Path -Parent $bridgeRoot
$taskRoot = Join-Path $workspaceRoot ('.opencode-tasks-test-' + [guid]::NewGuid().ToString('N'))
$newTask = Join-Path $bridgeRoot 'New-OpenCodeTask.ps1'
$invokeTask = Join-Path $bridgeRoot 'Invoke-OpenCodeTask.ps1'
$resumeTask = Join-Path $bridgeRoot 'Resume-OpenCodeTask.ps1'
$getResult = Join-Path $bridgeRoot 'Get-OpenCodeTaskResult.ps1'
$waitTask = Join-Path $bridgeRoot 'Wait-OpenCodeTask.ps1'
$startTask = Join-Path $bridgeRoot 'Start-OpenCodeTask.ps1'
$openOpenCode = Join-Path $bridgeRoot 'Open-OpenCode.ps1'
$backgroundRunner = Join-Path $bridgeRoot 'Run-OpenCodeTaskBackground.ps1'
$recoverTask = Join-Path $bridgeRoot 'Recover-OpenCodeTask.ps1'
$listTasks = Join-Path $bridgeRoot 'List-OpenCodeTasks.ps1'
$cleanupReport = Join-Path $bridgeRoot 'Get-OpenCodeLogCleanup.ps1'
$removeLog = Join-Path $bridgeRoot 'Remove-OpenCodeTaskLog.ps1'
$bridgeConfigPath = Join-Path $bridgeRoot 'config.json'
$versionPath = Join-Path $bridgeRoot 'VERSION'
$skillPath = 'C:\Users\Administrator\.codex\skills\opencode-sidecar\SKILL.md'
$openCodeConfig = Join-Path $bridgeRoot 'opencode-config\opencode.json'
$failures = [System.Collections.Generic.List[string]]::new()

function Assert-True {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) {
        $script:failures.Add($Message)
    }
}

function Assert-Equal {
    param($Actual, $Expected, [string]$Message)
    if ($Actual -ne $Expected) {
        $script:failures.Add("$Message (expected=$Expected actual=$Actual)")
    }
}

foreach ($path in @($newTask, $invokeTask, $resumeTask, $getResult, $waitTask, $startTask, $openOpenCode, $backgroundRunner, $recoverTask, $listTasks, $cleanupReport, $removeLog, $versionPath, $skillPath)) {
    Assert-True (Test-Path -LiteralPath $path) "Missing implementation file: $path"
}
$startTaskText = Get-Content -LiteralPath $startTask -Raw
Assert-True ($startTaskText -match 'Open-OpenCode\.ps1') 'Task start must recover an unavailable OpenCode Web server'
Assert-True ($startTaskText -match '\[switch\]\$Wait') 'Task start must support one-call local waiting'
$commonText = Get-Content -LiteralPath (Join-Path $bridgeRoot 'Common.ps1') -Raw
Assert-True ($commonText -match "'/api/session'") 'Session creation must use the UTF-8-safe V2 API'
Assert-True ($commonText -match 'monitor\.md') 'Bridge must generate a task monitor markdown artifact'
Assert-True ($commonText -match 'monitor\.html') 'Bridge must generate a task monitor HTML artifact'
if (Test-Path -LiteralPath $skillPath) {
    $skillText = Get-Content -LiteralPath $skillPath -Raw -Encoding utf8
    Assert-True ($skillText -match 'Start-OpenCodeTask\.ps1.*-Wait') 'Skill must use the V2 blocking wait path'
    Assert-True ($skillText -notmatch 'Poll with `Get-OpenCodeTaskResult') 'Skill must not instruct Codex to poll repeatedly'
    Assert-True ($skillText -match 'EEXIST') 'Skill must document the known restricted-profile startup failure'
    Assert-True ($skillText -match '-Retry -Wait') 'Skill must retry the same task and wait after a restricted-profile startup failure'
}

foreach ($agent in @('research', 'repo-readonly', 'repo-write')) {
    $agentPath = Join-Path $bridgeRoot "opencode-config\agents\$agent.md"
    Assert-True (Test-Path -LiteralPath $agentPath) "Missing agent: $agentPath"
    if (Test-Path -LiteralPath $agentPath) {
        $agentText = Get-Content -LiteralPath $agentPath -Raw
        Assert-True ($agentText -match '"\*": deny') "Agent must deny unspecified tools: $agent"
    }
}
Assert-True (Test-Path -LiteralPath $openCodeConfig) 'Missing dedicated OpenCode config'
if (Test-Path -LiteralPath $openCodeConfig) {
    $sidecarConfig = Get-Content -LiteralPath $openCodeConfig -Raw | ConvertFrom-Json
    Assert-Equal $sidecarConfig.permission.'*' 'deny' 'Dedicated server denies unspecified permissions globally'
}
Assert-True (Test-Path -LiteralPath $bridgeConfigPath) 'Missing bridge config'
if (Test-Path -LiteralPath $bridgeConfigPath) {
    $bridgeConfig = Get-Content -LiteralPath $bridgeConfigPath -Raw | ConvertFrom-Json
    Assert-True (@($bridgeConfig.allowedModels).Count -gt 0) 'Bridge config must define allowedModels'
    Assert-True (@($bridgeConfig.allowedModels) -contains $bridgeConfig.defaultModel) 'Default model must be in allowedModels'
    Assert-True (@($bridgeConfig.allowedModels) -contains 'opencode-go/deepseek-v4-pro') 'OpenCode Go Pro model must be allowed for future subscription use'
    Assert-True ($null -ne $bridgeConfig.allowedPassEnv) 'Bridge config must define allowedPassEnv'
    Assert-Equal $bridgeConfig.bridgeVersion '3.0.0' 'Bridge config must identify V3'
    Assert-True ([int]$bridgeConfig.waitPollIntervalMilliseconds -ge 250) 'V2 wait interval must be configured'
    Assert-True ([int]$bridgeConfig.maxResultCharacters -ge 1000) 'V2 result budget must be configured'
}
if (Test-Path -LiteralPath $versionPath) {
    Assert-Equal ((Get-Content -LiteralPath $versionPath -Raw).Trim()) '3.0.0' 'VERSION file must identify V3'
}

if ($SchemaOnly -or $failures.Count -gt 0) {
    if ($failures.Count -gt 0) {
        $failures | ForEach-Object { Write-Error $_ -ErrorAction Continue }
        exit 1
    }
    Write-Host 'Schema checks passed.'
    exit 0
}

New-Item -ItemType Directory -Path $taskRoot | Out-Null

$fakeArgs = Join-Path $taskRoot 'fake-args.txt'
$fakeEnv = Join-Path $taskRoot 'fake-env.txt'
$fakeCli = Join-Path $taskRoot 'fake-opencode.ps1'
$escapedFakeArgs = $fakeArgs.Replace("'", "''")
$escapedFakeEnv = $fakeEnv.Replace("'", "''")
@"
(`$args -join ' ') | Add-Content -LiteralPath '$escapedFakeArgs' -Encoding utf8
(`$env:OPENCODE_CONFIG + '|' + `$env:OPENCODE_CONFIG_DIR + '|HTTP_PROXY=' + `$env:HTTP_PROXY) | Add-Content -LiteralPath '$escapedFakeEnv' -Encoding utf8
`$sessionId = 'ses_fake_123'
`$sessionIndex = [Array]::IndexOf(`$args, '--session')
if (`$sessionIndex -ge 0) { `$sessionId = `$args[`$sessionIndex + 1] }
Write-Output ('{"type":"step_start","sessionID":"' + `$sessionId + '","part":{"type":"step-start"}}')
Write-Output ('{"type":"text","sessionID":"' + `$sessionId + '","part":{"type":"text","text":"FAKE_RESULT"}}')
Write-Output ('{"type":"step_finish","sessionID":"' + `$sessionId + '","part":{"type":"step-finish"}}')
"@ | Set-Content -LiteralPath $fakeCli -Encoding utf8

& $newTask -TaskId 'readonly-check' -Goal 'Inspect supplied public text.' -Mode 'repo-readonly' -TaskRoot $taskRoot -Workdir $workspaceRoot -ExternalDisclosureApproval yes | Out-Null
$statusPath = Join-Path $taskRoot 'readonly-check\status.json'
$status = Get-Content -LiteralPath $statusPath -Raw | ConvertFrom-Json
Assert-Equal $status.state 'draft' 'New tasks start in draft state'
Assert-Equal $status.mode 'repo-readonly' 'Task mode is persisted'
Assert-Equal $status.model 'opencode/deepseek-v4-flash-free' 'Default model is persisted'
Assert-Equal @($status.passEnv).Count 0 'PassEnv defaults to empty'
Assert-Equal $status.bridgeVersion '3.0.0' 'New tasks record the V3 bridge version'
$taskBrief = Get-Content -LiteralPath (Join-Path $taskRoot 'readonly-check\task.md') -Raw
Assert-True ($taskBrief -match '6000 characters') 'V2 task brief constrains the final result size'
Assert-True ($taskBrief -match 'conclusion first') 'V2 task brief requires conclusion-first output'

& $invokeTask -TaskId 'readonly-check' -TaskRoot $taskRoot -OpenCodePath $fakeCli -NoServer | Out-Null
$status = Get-Content -LiteralPath $statusPath -Raw | ConvertFrom-Json
Assert-Equal $status.state 'idle' 'Successful task becomes idle and resumable'
Assert-Equal $status.sessionId 'ses_fake_123' 'Session ID is recorded'
Assert-True (Test-Path -LiteralPath (Join-Path $taskRoot 'readonly-check\result.md')) 'Result Markdown is written'
Assert-True (Test-Path -LiteralPath (Join-Path $taskRoot 'readonly-check\monitor.md')) 'Task monitor markdown is written'
Assert-True (Test-Path -LiteralPath (Join-Path $taskRoot 'readonly-check\monitor.html')) 'Task monitor HTML is written'

$arguments = Get-Content -LiteralPath $fakeArgs -Raw
Assert-True ($arguments -match '--agent repo-readonly') 'Read-only agent is selected'
Assert-True ($arguments -match '--file') 'Task Markdown is attached'
$environment = Get-Content -LiteralPath $fakeEnv -Raw
Assert-True ($environment -match [regex]::Escape($openCodeConfig)) 'Worker receives the dedicated OpenCode config path'
Assert-True ($environment -match [regex]::Escape((Join-Path $bridgeRoot 'opencode-config'))) 'Worker receives the custom agents directory'

& $newTask -TaskId 'model-check' -Goal 'Use an allowed model.' -Mode 'research' -Model 'deepseek/deepseek-v4-pro' -TaskRoot $taskRoot -Workdir $workspaceRoot -ExternalDisclosureApproval yes | Out-Null
& $invokeTask -TaskId 'model-check' -TaskRoot $taskRoot -OpenCodePath $fakeCli -NoServer | Out-Null
$modelArguments = Get-Content -LiteralPath $fakeArgs | Where-Object { $_ -match 'model-check' } | Select-Object -Last 1
Assert-True ($modelArguments -match '--model deepseek/deepseek-v4-pro') 'Allowed task model reaches the OpenCode CLI'

$modelRejected = $false
try {
    & $newTask -TaskId 'invalid-model-check' -Goal 'Reject an unknown model.' -Mode 'research' -Model 'unknown/provider-model' -TaskRoot $taskRoot -Workdir $workspaceRoot -ExternalDisclosureApproval yes -ErrorAction Stop | Out-Null
} catch {
    $modelRejected = $true
}
Assert-True $modelRejected 'Unknown models are rejected before task creation'

$oldHttpProxy = $env:HTTP_PROXY
try {
    $env:HTTP_PROXY = 'http://proxy.test:8080'
    & $newTask -TaskId 'pass-env-check' -Goal 'Use one approved environment variable.' -Mode 'research' -PassEnv @('HTTP_PROXY') -TaskRoot $taskRoot -Workdir $workspaceRoot -ExternalDisclosureApproval yes | Out-Null
    & $invokeTask -TaskId 'pass-env-check' -TaskRoot $taskRoot -OpenCodePath $fakeCli -NoServer | Out-Null
} finally {
    $env:HTTP_PROXY = $oldHttpProxy
}
$passEnvStatus = Get-Content -LiteralPath (Join-Path $taskRoot 'pass-env-check\status.json') -Raw | ConvertFrom-Json
Assert-True (@($passEnvStatus.passEnv) -contains 'HTTP_PROXY') 'Approved environment variable name is persisted'
$environment = Get-Content -LiteralPath $fakeEnv -Raw
Assert-True ($environment -match 'HTTP_PROXY=http://proxy\.test:8080') 'Approved environment variable is available to the worker'

$passEnvRejected = $false
try {
    & $newTask -TaskId 'invalid-env-check' -Goal 'Reject a sensitive variable.' -Mode 'research' -PassEnv @('DEEPSEEK_API_KEY') -TaskRoot $taskRoot -Workdir $workspaceRoot -ExternalDisclosureApproval yes -ErrorAction Stop | Out-Null
} catch {
    $passEnvRejected = $true
}
Assert-True $passEnvRejected 'Environment variables outside the allowlist are rejected'

& $newTask -TaskId 'write-check' -Goal 'Edit one authorized file.' -Mode 'repo-write' -TaskRoot $taskRoot -Workdir $workspaceRoot -ExternalDisclosureApproval yes | Out-Null
$writeRejected = $false
try {
    & $invokeTask -TaskId 'write-check' -TaskRoot $taskRoot -OpenCodePath $fakeCli -NoServer -ErrorAction Stop | Out-Null
} catch {
    $writeRejected = $true
}
Assert-True $writeRejected 'Write mode is rejected without one-time authorization'

& $invokeTask -TaskId 'write-check' -TaskRoot $taskRoot -OpenCodePath $fakeCli -NoServer -AuthorizeWrite | Out-Null
$writeStatus = Get-Content -LiteralPath (Join-Path $taskRoot 'write-check\status.json') -Raw | ConvertFrom-Json
Assert-Equal $writeStatus.state 'idle' 'Authorized write invocation completes'

& $newTask -TaskId 'prepared-session-check' -Goal 'Use a session created before execution.' -Mode 'research' -TaskRoot $taskRoot -Workdir $workspaceRoot -ExternalDisclosureApproval yes | Out-Null
$preparedStatusPath = Join-Path $taskRoot 'prepared-session-check\status.json'
$preparedStatus = Get-Content -LiteralPath $preparedStatusPath -Raw | ConvertFrom-Json
$preparedStatus.sessionId = 'ses_prepared_123'
$preparedStatus | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $preparedStatusPath -Encoding utf8
& $invokeTask -TaskId 'prepared-session-check' -TaskRoot $taskRoot -OpenCodePath $fakeCli -NoServer -PreparedSession | Out-Null
$preparedArguments = Get-Content -LiteralPath $fakeArgs | Where-Object { $_ -match '--agent research' -and $_ -match 'prepared-session-check' } | Select-Object -Last 1
Assert-True ($preparedArguments -match '--session ses_prepared_123') 'Worker reuses a session created before execution'
$preparedStatus = Get-Content -LiteralPath $preparedStatusPath -Raw | ConvertFrom-Json
Assert-Equal $preparedStatus.sessionId 'ses_prepared_123' 'Prepared session ID remains stable'

$followUp = Join-Path $taskRoot 'follow-up.md'
'Return the same session ID.' | Set-Content -LiteralPath $followUp -Encoding utf8
& $resumeTask -TaskId 'readonly-check' -FollowUpFile $followUp -TaskRoot $taskRoot -OpenCodePath $fakeCli -NoServer | Out-Null
$arguments = Get-Content -LiteralPath $fakeArgs -Raw
Assert-True ($arguments -match '--session ses_fake_123') 'Resume reuses the recorded session ID'

$resultInfo = & $getResult -TaskId 'readonly-check' -TaskRoot $taskRoot -Json | ConvertFrom-Json
Assert-Equal $resultInfo.state 'idle' 'Result reader reports idle state'
Assert-Equal $resultInfo.sessionId 'ses_fake_123' 'Result reader returns session ID'
$directoryToken = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($workspaceRoot)).TrimEnd('=').Replace('+', '-').Replace('/', '_')
Assert-Equal $resultInfo.webUrl "http://127.0.0.1:4096/$directoryToken/session/ses_fake_123" 'Result reader returns the canonical project session URL'
Assert-Equal $resultInfo.model 'opencode/deepseek-v4-flash-free' 'Result reader returns the task model'
Assert-True ($resultInfo.monitorPath -match 'monitor\.md$') 'Result reader returns the task monitor markdown path'
Assert-True ($resultInfo.monitorHtmlPath -match 'monitor\.html$') 'Result reader returns the task monitor HTML path'

$listedTasks = & $listTasks -TaskRoot $taskRoot -Json | ConvertFrom-Json
$listedReadonly = @($listedTasks) | Where-Object { $_.taskId -eq 'readonly-check' } | Select-Object -First 1
Assert-True ($null -ne $listedReadonly) 'Task listing includes existing tasks'
Assert-Equal $listedReadonly.model 'opencode/deepseek-v4-flash-free' 'Task listing includes model metadata'

& $newTask -TaskId 'background-check' -Goal 'Run without blocking the caller.' -Mode 'research' -TaskRoot $taskRoot -Workdir $workspaceRoot -ExternalDisclosureApproval yes | Out-Null
& $startTask -TaskId 'background-check' -TaskRoot $taskRoot -OpenCodePath $fakeCli -NoServer | Out-Null
$backgroundStatusPath = Join-Path $taskRoot 'background-check\status.json'
$waitedBackground = & $waitTask -TaskId 'background-check' -TaskRoot $taskRoot -TimeoutSeconds 10 -PollIntervalMilliseconds 100
Assert-Equal $waitedBackground.state 'idle' 'Local waiter observes background completion'
Assert-Equal $waitedBackground.result 'FAKE_RESULT' 'Local waiter returns the final concise result once'
Assert-True ($waitedBackground.monitorPath -match 'monitor\.md$') 'Local waiter returns the monitor markdown path'
Assert-True ($waitedBackground.monitorHtmlPath -match 'monitor\.html$') 'Local waiter returns the monitor HTML path'
Assert-True (Test-Path -LiteralPath (Join-Path $taskRoot 'background-check\background.stderr.log')) 'Background stderr log is retained'
$backgroundArguments = Get-Content -LiteralPath $fakeArgs | Where-Object { $_ -match '--agent research' } | Select-Object -Last 1
Assert-True ($backgroundArguments -match ('--dir ' + [regex]::Escape($workspaceRoot))) 'Research sessions belong to the requested project directory for Web visibility'

& $newTask -TaskId 'start-wait-check' -Goal 'Start and wait in one bridge command.' -Mode 'research' -TaskRoot $taskRoot -Workdir $workspaceRoot -ExternalDisclosureApproval yes | Out-Null
$startWaitResult = & $startTask -TaskId 'start-wait-check' -TaskRoot $taskRoot -OpenCodePath $fakeCli -NoServer -Wait -WaitTimeoutSeconds 10 -WaitPollIntervalMilliseconds 100
Assert-Equal $startWaitResult.state 'idle' 'Start -Wait returns only after the task reaches a terminal state'
Assert-Equal $startWaitResult.result 'FAKE_RESULT' 'Start -Wait returns the final result'

& $newTask -TaskId 'draft-wait-check' -Goal 'Do not wait before starting.' -Mode 'research' -TaskRoot $taskRoot -Workdir $workspaceRoot -ExternalDisclosureApproval yes | Out-Null
$draftWaitRejected = $false
try {
    & $waitTask -TaskId 'draft-wait-check' -TaskRoot $taskRoot -TimeoutSeconds 1 -PollIntervalMilliseconds 100 -ErrorAction Stop | Out-Null
} catch {
    $draftWaitRejected = $true
}
Assert-True $draftWaitRejected 'Waiting on a draft task is rejected immediately'

$exportCli = Join-Path $taskRoot 'fake-opencode-export.ps1'
@'
if ($args[0] -eq 'export') {
    Write-Error 'Exporting session: ses_export_123'
    Write-Output '{"messages":[{"info":{"role":"assistant"},"parts":[{"type":"text","text":"EXPORT_RESULT"}]}]}'
    exit 0
}
Write-Output '{"type":"step_start","sessionID":"ses_export_123","part":{"type":"step-start"}}'
Write-Output '{"type":"step_finish","sessionID":"ses_export_123","part":{"type":"step-finish"}}'
'@ | Set-Content -LiteralPath $exportCli -Encoding utf8
& $newTask -TaskId 'export-fallback' -Goal 'Recover the result from the session export.' -Mode 'research' -TaskRoot $taskRoot -Workdir $workspaceRoot -ExternalDisclosureApproval yes | Out-Null
& $invokeTask -TaskId 'export-fallback' -TaskRoot $taskRoot -OpenCodePath $exportCli -NoServer | Out-Null
$exportResult = Get-Content -LiteralPath (Join-Path $taskRoot 'export-fallback\result.md') -Raw
Assert-True ($exportResult -match 'EXPORT_RESULT') 'Session export recovers a missing streamed final result'

& $newTask -TaskId 'recover-check' -Goal 'Recover a completed server session.' -Mode 'research' -TaskRoot $taskRoot -Workdir $workspaceRoot -ExternalDisclosureApproval yes | Out-Null
$recoverDirectory = Join-Path $taskRoot 'recover-check'
$recoverStatusPath = Join-Path $recoverDirectory 'status.json'
$recoverStatus = Get-Content -LiteralPath $recoverStatusPath -Raw | ConvertFrom-Json
$recoverStatus.state = 'failed'
$recoverStatus | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $recoverStatusPath -Encoding utf8
'{"type":"step_start","sessionID":"ses_recover_123","part":{"type":"step-start"}}' | Set-Content -LiteralPath (Join-Path $recoverDirectory 'invocation-test.jsonl') -Encoding utf8
$messagesFile = Join-Path $recoverDirectory 'messages-fixture.json'
'[{"info":{"role":"assistant"},"parts":[{"type":"text","text":"恢复结果"}]}]' | Set-Content -LiteralPath $messagesFile -Encoding utf8
& $recoverTask -TaskId 'recover-check' -TaskRoot $taskRoot -MessagesFile $messagesFile | Out-Null
$recoverStatus = Get-Content -LiteralPath $recoverStatusPath -Raw | ConvertFrom-Json
Assert-Equal $recoverStatus.state 'idle' 'Recovery returns a completed server session to idle'
Assert-Equal $recoverStatus.sessionId 'ses_recover_123' 'Recovery records the server session ID'
$recoveredText = Get-Content -LiteralPath (Join-Path $recoverDirectory 'result.md') -Raw
Assert-True ($recoveredText -match '恢复结果') 'Recovery preserves UTF-8 result text'

$oldLog = Join-Path $recoverDirectory 'invocation-old.jsonl'
'old log' | Set-Content -LiteralPath $oldLog -Encoding utf8
(Get-Item -LiteralPath $oldLog).LastWriteTime = (Get-Date).AddDays(-45)
$cleanupCandidates = @(& $cleanupReport -TaskId 'recover-check' -TaskRoot $taskRoot -OlderThanDays 30)
Assert-True (@($cleanupCandidates.fileName) -contains 'invocation-old.jsonl') 'Cleanup report identifies old disposable logs'
& $removeLog -TaskId 'recover-check' -FileName 'invocation-old.jsonl' -TaskRoot $taskRoot | Out-Null
Assert-True (-not (Test-Path -LiteralPath $oldLog)) 'Single-file cleanup removes the explicit log'
$protectedRemovalRejected = $false
try {
    & $removeLog -TaskId 'recover-check' -FileName 'result.md' -TaskRoot $taskRoot -ErrorAction Stop | Out-Null
} catch {
    $protectedRemovalRejected = $true
}
Assert-True $protectedRemovalRejected 'Cleanup refuses protected task artifacts'
Assert-True (Test-Path -LiteralPath (Join-Path $recoverDirectory 'result.md')) 'Cleanup preserves task results'

if ($failures.Count -gt 0) {
    $failures | ForEach-Object { Write-Error $_ -ErrorAction Continue }
    exit 1
}

Write-Host 'All OpenCode sidecar bridge tests passed.'
