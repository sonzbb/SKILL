$ErrorActionPreference = 'Stop'

$skillRoot = 'C:\Users\Administrator\.codex\skills\opencode-sidecar'
$skillFile = Join-Path $skillRoot 'SKILL.md'
$agentFile = Join-Path $skillRoot 'agents\openai.yaml'
$failures = [System.Collections.Generic.List[string]]::new()

function Assert-True {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { $script:failures.Add($Message) }
}

Assert-True (Test-Path -LiteralPath $skillFile) 'Global opencode-sidecar SKILL.md is missing'
Assert-True (Test-Path -LiteralPath $agentFile) 'Global opencode-sidecar agents/openai.yaml is missing'

if (Test-Path -LiteralPath $skillFile) {
    $text = Get-Content -LiteralPath $skillFile -Raw
    Assert-True ($text -match 'name:\s*opencode-sidecar') 'Skill name is incorrect'
    Assert-True ($text -match 'D:\\CODEX项目\\\.opencode-bridge') 'Bridge path is missing'
    foreach ($mode in @('research', 'repo-readonly', 'repo-write')) {
        Assert-True ($text -match [regex]::Escape($mode)) "Missing mode guidance: $mode"
    }
    Assert-True ($text -match 'AuthorizeWrite') 'One-time write authorization is not documented'
    Assert-True ($text -match 'Resume-OpenCodeTask') 'Session resume workflow is missing'
    Assert-True ($text -notmatch 'sk-[A-Za-z0-9]{20,}') 'Skill contains an API-key-like value'
    Assert-True ($text -notmatch 'deepseek-v[0-9]') 'Skill hard-codes a model ID'
}

if ($failures.Count -gt 0) {
    $failures | ForEach-Object { Write-Error $_ -ErrorAction Continue }
    exit 1
}

Write-Host 'OpenCode sidecar skill checks passed.'
