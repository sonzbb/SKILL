param(
    [Parameter(Mandatory)][string]$TaskId,
    [Parameter(Mandatory)][string]$Goal,
    [ValidateSet('research', 'repo-readonly', 'repo-write')][string]$Mode = 'repo-readonly',
    [ValidateSet('yes', 'no')][string]$ExternalDisclosureApproval = 'no',
    [string]$Model,
    [string[]]$PassEnv = @(),
    [string]$Workdir = (Get-Location).Path,
    [string]$TaskRoot
)

. (Join-Path $PSScriptRoot 'Common.ps1')
Assert-TaskId $TaskId
if ([string]::IsNullOrWhiteSpace($Goal)) { throw 'Goal cannot be empty.' }
$resolvedModel = Resolve-OpenCodeTaskModel $Model
$resolvedPassEnv = Resolve-OpenCodePassEnvNames $PassEnv
$config = Get-BridgeConfig

$directory = Get-TaskDirectory $TaskRoot $TaskId
if (Test-Path -LiteralPath $directory) { throw "Task already exists: $TaskId" }
New-Item -ItemType Directory -Path $directory | Out-Null

$task = @"
# OpenCode Sidecar Task

## Task ID
$TaskId

## Mode
$Mode

## Model
$resolvedModel

## Passed Environment Variable Names
$(if ($resolvedPassEnv.Count -gt 0) { $resolvedPassEnv -join ', ' } else { 'None' })

## Goal
$Goal

## Context
Add only the context required for this bounded task.

## Allowed Paths
$([System.IO.Path]::GetFullPath($Workdir))

## Prohibited Actions
- Do not exceed the permissions of the selected worker mode.
- Do not access paths outside the working directory.
- Do not publish, commit, push, or delete files.

## Expected Result
- Put the conclusion first.
- Keep the final report under $($config.maxResultCharacters) characters.
- Include only essential evidence, missing information, and next actions.
- Cite detailed artifact or log paths instead of copying long logs into the report.

## External Disclosure Approval
$ExternalDisclosureApproval
"@
$task | Set-Content -LiteralPath (Join-Path $directory 'task.md') -Encoding utf8

$status = [ordered]@{
    bridgeVersion = [string]$config.bridgeVersion
    taskId = $TaskId
    state = 'draft'
    mode = $Mode
    model = $resolvedModel
    passEnv = @($resolvedPassEnv)
    workdir = [System.IO.Path]::GetFullPath($Workdir)
    externalDisclosureApproval = $ExternalDisclosureApproval
    sessionId = $null
    webUrl = $null
    monitorProcessId = $null
    monitorType = $null
    createdAt = (Get-Date).ToString('o')
    startedAt = $null
    finishedAt = $null
    lastExitCode = $null
    lastLogPath = $null
    resultPath = $null
}
Write-TaskStatus $directory $status
Write-Output $directory
