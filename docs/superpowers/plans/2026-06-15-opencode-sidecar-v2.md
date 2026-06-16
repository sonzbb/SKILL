# OpenCode Sidecar V2 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace repeated Codex-driven OpenCode polling with one local blocking wait and a compact final result.

**Architecture:** A focused PowerShell waiter reads each task's atomic `status.json` until a terminal state. `Start-OpenCodeTask.ps1` optionally delegates to that waiter, while task creation adds version and concise-result instructions.

**Tech Stack:** PowerShell 5.1, JSON task status files, existing OpenCode CLI bridge tests.

---

### Task 1: V2 Contract Tests

**Files:**
- Modify: `.opencode-bridge/tests/Test-Bridge.ps1`

- [ ] Add schema checks for the V2 waiter, version marker, configuration, and non-polling Skill instructions.
- [ ] Add behavior checks for waiting on a background task, integrated `Start -Wait`, and rejecting draft tasks.
- [ ] Run the schema test and confirm it fails only because V2 is not implemented yet.

### Task 2: Local Waiter

**Files:**
- Create: `.opencode-bridge/Wait-OpenCodeTask.ps1`
- Modify: `.opencode-bridge/Start-OpenCodeTask.ps1`

- [ ] Implement silent local status waiting with configurable timeout and interval.
- [ ] Return one object containing terminal state, session URL, paths, and concise result text.
- [ ] Add `-Wait` to task startup and route it through the waiter.
- [ ] Run the bridge tests and confirm waiting behavior passes.

### Task 3: Version And Result Budget

**Files:**
- Create: `.opencode-bridge/VERSION`
- Modify: `.opencode-bridge/config.json`
- Modify: `.opencode-bridge/New-OpenCodeTask.ps1`

- [ ] Add bridge version `2.0.0`, wait defaults, and result character budget.
- [ ] Persist the bridge version on new tasks.
- [ ] Put conclusion-first, compact-result requirements in generated task briefs.

### Task 4: V2 Workflow Documentation

**Files:**
- Modify: `.opencode-bridge/README.md`
- Modify: `C:/Users/Administrator/.codex/skills/opencode-sidecar/SKILL.md`

- [ ] Make `Start-OpenCodeTask.ps1 -Wait` the normal delegation path.
- [ ] Retain Web monitoring instructions and explain that `Get-OpenCodeTaskResult.ps1` is diagnostic only.
- [ ] Validate the Skill format and scan it for obsolete polling instructions.

### Task 5: Verification

**Files:**
- Test: `.opencode-bridge/tests/Test-Bridge.ps1`

- [ ] Run schema and full bridge tests.
- [ ] Run a real bounded OpenCode task through `Start -Wait`.
- [ ] Confirm one terminal response, saved `result.md`, healthy Web session, and no repeated external status loop.

