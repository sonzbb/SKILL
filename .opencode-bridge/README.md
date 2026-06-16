# OpenCode Sidecar V2

Codex uses this bridge to delegate bounded work to OpenCode while retaining planning, review, and final decision responsibility.

## Modes

- `research`: public web research only.
- `repo-readonly`: repository inspection and bounded verification; no edits.
- `repo-write`: edits require `-AuthorizeWrite` on every invocation.

## Task Sizing

Use Codex directly when the task is small and judgment-heavy:

- narrow scope, usually one question or one concrete decision
- limited material, roughly a few files, pages, or screenshots
- little to no long-log reading, batch scanning, or repeated simulation
- the main value is planning, tradeoff judgment, or final synthesis

Use OpenCode sidecar when the task is long and bounded:

- large-scale collection, scanning, summarization, or enumeration
- long logs, many files, many pages, or repeated trial runs
- the deliverable can be defined in advance as `result.md`, notes, or cited evidence

Working rule: Codex should do the deciding work first. OpenCode should do the hauling, collecting, scanning, and repetitive material processing.

## Model Routing Policy

Task mode and model are separate choices. First decide whether the task stays in Codex or goes to sidecar, then choose the OpenCode mode, then choose the model.

See [MODEL-ROUTING.md](./MODEL-ROUTING.md) for the detailed policy. The short version is:

- image-first or multimodal work: prefer a multimodal model such as `MIMO V2.5`
- text-only collection and quick organization: prefer `DeepSeek V4 Flash`
- deeper root-cause analysis or harder synthesis: prefer `DeepSeek V4 Pro`
- smoke tests, chain validation, or cheapest trial runs: prefer `flash-free`

This policy may mention preferred models that are not yet configured in `config.json`. In that case the policy still defines the intended routing, but the concrete bridge invocation must fall back to an allowed configured model until the preferred one is added.

The dedicated `opencode-config/opencode.json` denies unspecified permissions globally, then the Markdown agents under `opencode-config/agents/` allow only each mode's required tools. The launch and worker scripts inject both `OPENCODE_CONFIG` and `OPENCODE_CONFIG_DIR`. These are guardrails, not an operating-system sandbox; Codex must still review task scope and results.

Sessions use the task's project directory so they appear together in the OpenCode Web project view. Research workers still cannot read project files because their agent permissions deny file and shell tools.

`Start-OpenCodeTask.ps1` creates the server session before execution and opens that exact session in the OpenCode Web UI. V2 adds `-Wait`: OpenCode keeps working in the background while one local PowerShell process waits silently and returns only the terminal result. Pass `-NoMonitor` only when a silent background run is explicitly required.

OpenCode 1.17.x session pages use `/<base64url-directory>/session/<session-id>`. The bridge creates sessions through `/api/session` with a UTF-8 JSON location so non-ASCII Windows paths stay attached to the correct Web project instead of falling back to `global`.

Before creating a session, task startup checks the configured Web server and automatically restarts it when it is unavailable.

## Create And Run

```powershell
.\.opencode-bridge\New-OpenCodeTask.ps1 -TaskId review-auth -Goal 'Review authentication code.' -Mode repo-readonly -ExternalDisclosureApproval yes -Workdir D:\path\to\repo
.\.opencode-bridge\Start-OpenCodeTask.ps1 -TaskId review-auth -Wait
```

For an already-started task, wait without creating external status checks:

```powershell
.\.opencode-bridge\Wait-OpenCodeTask.ps1 -TaskId review-auth
```

`Get-OpenCodeTaskResult.ps1` remains available for manual diagnosis. It is not the normal waiting loop in V2. New task briefs require conclusion-first reports below `maxResultCharacters` and ask the worker to cite log paths instead of copying large logs into `result.md`.

If a restricted Windows process fails before invocation logging with `EEXIST` or access denied for the OpenCode profile directory, rerun the same task under normal user permission with `-Retry -Wait`. This reuses the existing task and Web session.

The configured default model is used unless the task selects another allowed model:

```powershell
.\.opencode-bridge\New-OpenCodeTask.ps1 -TaskId deep-review -Goal 'Review a large diff.' -Mode repo-readonly -Model 'deepseek/deepseek-v4-pro' -ExternalDisclosureApproval yes -Workdir D:\path\to\repo
```

`config.json` contains the exact `allowedModels` list. A task with any other model is rejected before creation, and the selected model is retained when the session is resumed.

Use `-PassEnv` only for names listed in `allowedPassEnv`:

```powershell
.\.opencode-bridge\New-OpenCodeTask.ps1 -TaskId proxy-research -Goal 'Collect public sources.' -Mode research -PassEnv HTTP_PROXY,HTTPS_PROXY -ExternalDisclosureApproval yes
```

Only variable names are stored in task metadata. Values must already exist in the launching process and are never written to `task.md` or `status.json`. This allowlist records and validates intentional task-specific variables; it is not an operating-system environment sandbox. Provider API keys should remain managed by OpenCode rather than being passed through a task.

## List Tasks

```powershell
.\.opencode-bridge\List-OpenCodeTasks.ps1
.\.opencode-bridge\List-OpenCodeTasks.ps1 -State running
```

## Log Cleanup

First list old disposable logs for one task:

```powershell
.\.opencode-bridge\Get-OpenCodeLogCleanup.ps1 -TaskId review-auth -OlderThanDays 30
```

Then remove one explicit log file:

```powershell
.\.opencode-bridge\Remove-OpenCodeTaskLog.ps1 -TaskId review-auth -FileName invocation-20260615-120000.jsonl
```

The remover accepts only `invocation-*.jsonl`, `background.stdout.log`, or `background.stderr.log`. It refuses active tasks and never removes `task.md`, `status.json`, `result.md`, or `session.json`.

## Resume

```powershell
.\.opencode-bridge\Resume-OpenCodeTask.ps1 -TaskId review-auth -FollowUpFile .\follow-up.md
```

If a server session completed but the CLI event stream ended before returning its final text:

```powershell
.\.opencode-bridge\Recover-OpenCodeTask.ps1 -TaskId review-auth
```

## Write Invocation

```powershell
.\.opencode-bridge\Invoke-OpenCodeTask.ps1 -TaskId implement-fix -AuthorizeWrite
```

`-AuthorizeWrite` applies only to that process invocation. It is not saved as a default.
