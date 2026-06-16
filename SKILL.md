---
name: opencode-sidecar-v3
description: Use when Codex should delegate bounded long-running, log-heavy, research, code-review, debugging, simulation, image-analysis, or repository exploration work to the configured local OpenCode sidecar while keeping Codex as planner, reviewer, and final decision-maker.
---

# OpenCode Sidecar V3

This skill lets Codex keep the main reasoning loop while offloading bounded heavy work to OpenCode.

Human-facing overview lives in [README.md](./README.md).  
Bridge implementation lives in [`.opencode-bridge/`](./.opencode-bridge/).

## Core Rule

- Codex handles planning, judgment, verification, and final answers.
- OpenCode handles hauling work: collection, scanning, long logs, repetitive bounded execution, and first-pass structured findings.

Do not delegate by default just because a worker exists. Delegate when the task is long, heavy, or materially repetitive.

## Step 1: Decide Task Size

Use Codex directly when the task is small and judgment-heavy:

- one narrow question
- one decision or one focused fix
- limited files, pages, logs, or screenshots
- little material hauling

Use OpenCode sidecar when the task is long and bounded:

- many files, pages, or sources
- long logs
- repeated checks or simulations
- repository-scale scanning
- structured first-pass review or collection

Plain-language rule:

- deciding work stays with Codex
- hauling work goes to OpenCode

## Step 2: Choose Mode

| Mode | Use for | Boundary |
| --- | --- | --- |
| `research` | public web research and data collection | no repository or shell access |
| `repo-readonly` | code review, logs, debugging, tests, repository exploration | no edits |
| `repo-write` | one specific implementation task | explicit per-invocation write approval required |

Never include API keys, `.env` contents, or unrelated private data in task briefs.

## Step 3: Choose Model Family

- image-first or multimodal work -> prefer a multimodal model such as `MIMO V2.5`
- text-only collection and quick organization -> prefer `DeepSeek V4 Flash`
- deeper root-cause analysis or harder synthesis -> prefer `DeepSeek V4 Pro`
- smoke tests, chain validation, or cheapest validation runs -> prefer `flash-free`

If the ideal model is not configured yet:

1. keep the same routing intent
2. choose the closest allowed configured model
3. state clearly that it is a fallback

## Step 4: Use The Bridge

Assume the bridge root is the repository copy of [`.opencode-bridge`](./.opencode-bridge/).

1. Ensure OpenCode Web is available:

```powershell
& '.\.opencode-bridge\Open-OpenCode.ps1' -Web
```

2. Create a task with a narrow, explicit goal:

```powershell
& '.\.opencode-bridge\New-OpenCodeTask.ps1' `
  -TaskId '<task-id>' `
  -Goal '<bounded goal>' `
  -Mode 'repo-readonly' `
  -Workdir '<absolute repo path>' `
  -ExternalDisclosureApproval yes
```

3. Inspect and, if needed, tighten the generated `task.md`.

4. Start the task and wait locally:

```powershell
& '.\.opencode-bridge\Start-OpenCodeTask.ps1' -TaskId '<task-id>' -Wait
```

Use `-AuthorizeWrite` only for an explicitly approved `repo-write` invocation.

## Monitoring Rule

V3 requires every dispatched task to expose a visible monitor entry.

After dispatch or result retrieval, capture and report:

- `monitorUrl`
- `monitorPath`
- `monitorHtmlPath`

Preferred user-facing behavior:

1. give the user the canonical `monitorUrl`
2. if the Codex browser is available, open that session there
3. if a local artifact is easier to share, use `monitor.html`

Do not only report `sessionId` and expect the user to reconstruct the URL manually.

## Waiting Rule

For long work, use one local blocking wait instead of repeated Codex status queries.

- prefer `Start-OpenCodeTask.ps1 -Wait`
- if a task was already started without waiting, use `Wait-OpenCodeTask.ps1`
- use `Get-OpenCodeTaskResult.ps1` only for manual diagnosis, not as a polling loop

The user can monitor the exact session in OpenCode Web while the local bridge waits. V3 makes that easier by returning monitor fields and writing monitor artifacts for each task.

## Review Rule

When the worker completes:

1. read the concise `result.md`
2. verify important evidence when needed
3. inspect diffs for write tasks
4. reject weak evidence or out-of-scope work
5. give the final answer as Codex

Do not treat OpenCode output as final truth without review.

## Continue A Task

For follow-up work on the same task:

```powershell
& '.\.opencode-bridge\Resume-OpenCodeTask.ps1' `
  -TaskId '<task-id>' `
  -FollowUpFile '<absolute follow-up.md path>'
```

For a `repo-write` follow-up, obtain fresh authorization and add `-AuthorizeWrite` again.

## Result Contract

OpenCode should return compact, conclusion-first results.

Expected shape:

- short conclusion first
- cited paths or artifacts
- no long raw logs copied into `result.md`
- clear boundary on what was and was not verified

## Example Trigger

User:

```text
先让 opencode 整理材料，你再做最终判断。
```

Codex should:

1. decide the task is sidecar-appropriate
2. choose mode and model
3. dispatch a bounded task
4. wait locally
5. review `result.md`
6. answer with Codex's final conclusion
