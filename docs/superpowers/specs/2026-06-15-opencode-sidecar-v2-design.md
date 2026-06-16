# OpenCode Sidecar V2 Design

## Goal

Reduce Codex token usage during long OpenCode work by replacing repeated model-driven status checks with one local blocking wait.

## Design

- Add `Wait-OpenCodeTask.ps1`. It reads `status.json` locally, emits no progress text, and returns one terminal result when the task becomes `idle` or `failed`.
- Add `Start-OpenCodeTask.ps1 -Wait` as the normal V2 path. OpenCode still runs in the background and remains visible in Web, while the caller waits in the same local process.
- Keep `Get-OpenCodeTaskResult.ps1` for manual inspection and diagnostics, not routine polling.
- Mark new tasks and configuration as bridge version `2.0.0` while preserving compatibility with existing task directories.
- Instruct OpenCode to put conclusions first, stay below the configured summary character limit, cite artifact paths, and avoid copying long logs into `result.md`.

## Error Handling

- Waiting on a draft task fails immediately.
- Waiting stops at the configured timeout and reports the latest observed state.
- A failed worker returns one terminal object with log and result paths so Codex can decide whether recovery or retry is appropriate.

## Success Criteria

- A background task can be started and awaited without external polling loops.
- `Start-OpenCodeTask.ps1 -Wait` returns the final result in one command.
- The global Skill no longer instructs Codex to poll repeatedly.
- Existing bridge behavior and tests remain green.

