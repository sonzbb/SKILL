# OpenCode Sidecar V2

OpenCode Sidecar V2 is a small bridge that lets Codex stay in charge while delegating bounded heavy work to OpenCode.

The intended split is simple:

- Codex plans, judges, verifies, and gives the final answer
- OpenCode collects, scans, summarizes, inspects long logs, and handles repetitive bounded execution

This repository contains the V2 bridge, task runner scripts, mode-specific OpenCode agent config, tests, and the working notes used to define the current behavior.

## What It Solves

This project is for the workflow where:

- expensive frontier reasoning should stay in Codex
- cheaper worker-style execution should go to OpenCode
- long or log-heavy tasks should not keep dragging Codex through repeated polling loops

V2 improves that flow by replacing repeated model-driven status checks with one local blocking wait. OpenCode keeps running in the background and remains visible in the Web UI, while the bridge returns one terminal result when the task finishes.

## Main Capabilities

- bounded task creation for OpenCode workers
- `research`, `repo-readonly`, and `repo-write` execution modes
- one-command `Start-OpenCodeTask.ps1 -Wait` flow
- saved `result.md` handoff back to Codex
- exact session opening in OpenCode Web
- model allowlist control through `config.json`
- worker routing guidance for text-first, deep-analysis, and multimodal tasks

## Repository Layout

- [`.opencode-bridge/`](./.opencode-bridge/) - bridge scripts, config, tests, and internal docs
- [`docs/superpowers/plans/2026-06-15-opencode-sidecar-v2.md`](./docs/superpowers/plans/2026-06-15-opencode-sidecar-v2.md) - implementation plan
- [`docs/superpowers/specs/2026-06-15-opencode-sidecar-v2-design.md`](./docs/superpowers/specs/2026-06-15-opencode-sidecar-v2-design.md) - design notes

## Modes

| Mode | Use for | Boundary |
| --- | --- | --- |
| `research` | public web research and data collection | no repository or shell access |
| `repo-readonly` | logs, repository exploration, debugging, code review | no edits |
| `repo-write` | one specific implementation task | explicit per-invocation write approval required |

## Task Routing

Use Codex directly when the task is small and judgment-heavy:

- one narrow decision
- limited files or pages
- little material hauling

Use OpenCode sidecar when the task is long and bounded:

- many pages or sources
- long logs
- many files
- repeated checks or simulation

Plain-language rule:

- deciding work stays with Codex
- hauling work goes to OpenCode

## Model Routing

The intended routing policy is:

- image-first or multimodal work -> prefer a multimodal model such as `MIMO V2.5`
- text-only collection and quick organization -> prefer `DeepSeek V4 Flash`
- deeper root-cause analysis or stronger synthesis -> prefer `DeepSeek V4 Pro`
- smoke tests and cheapest workflow validation -> prefer `flash-free`

The full policy is documented in [`.opencode-bridge/MODEL-ROUTING.md`](./.opencode-bridge/MODEL-ROUTING.md).

## Quick Start

Create a task:

```powershell
.\.opencode-bridge\New-OpenCodeTask.ps1 `
  -TaskId review-auth `
  -Goal "Inspect authentication flow and summarize risks." `
  -Mode repo-readonly `
  -Workdir D:\path\to\repo `
  -ExternalDisclosureApproval yes
```

Start the task and wait for one final result:

```powershell
.\.opencode-bridge\Start-OpenCodeTask.ps1 -TaskId review-auth -Wait
```

This opens the exact OpenCode Web session and returns when the task reaches a terminal state.

## Verification

Bridge and skill checks are covered by:

- [`.opencode-bridge/tests/Test-Bridge.ps1`](./.opencode-bridge/tests/Test-Bridge.ps1)
- [`.opencode-bridge/tests/Test-OpenCodeSidecarSkill.ps1`](./.opencode-bridge/tests/Test-OpenCodeSidecarSkill.ps1)

## Notes

- OpenCode provider authentication remains managed by OpenCode itself
- model selection is restricted by the bridge allowlist in [`.opencode-bridge/config.json`](./.opencode-bridge/config.json)
- `repo-write` should be used only for explicitly authorized write tasks
