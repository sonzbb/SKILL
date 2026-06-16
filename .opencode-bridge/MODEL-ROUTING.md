# OpenCode Sidecar Model Routing

This file defines the intended routing policy for Codex and OpenCode sidecar. It is a decision rule, not a guarantee that every named model is already configured.

## Core Principle

- Codex handles planning, judgment, prioritization, and final conclusions.
- OpenCode handles hauling work: collection, scanning, summarization, long logs, and repetitive bounded execution.

In plain language:

- judge first with Codex
- delegate heavy material work to OpenCode

## Step 1: Decide Task Size

### Small Task -> Codex Directly

Treat a task as small when most of the value is thinking rather than hauling:

- one narrow question, one decision, or one focused fix
- limited context, usually a few files, pages, screenshots, or logs
- no broad web collection
- no repository-wide scan
- no repeated simulation loop

Examples:

- compare two implementation options
- explain one error trace
- review one small config change
- inspect one screenshot and give a conclusion

### Long Task -> OpenCode Sidecar

Treat a task as long when the heavy part is material processing:

- gather many sources
- read long logs
- scan many files
- summarize repeated findings
- run bounded retries, checks, or simulations

Examples:

- collect public evidence for several matches
- scan a repository for all auth-related entry points
- read a long failing job log and extract patterns
- run a structured first-pass code review across many files

## Step 2: Choose Mode

| Mode | Use for | Boundary |
| --- | --- | --- |
| `research` | public web research and data collection | no repository or shell access |
| `repo-readonly` | repository reading, logs, debugging, code review, test inspection | no edits |
| `repo-write` | one specific implementation task | requires explicit per-invocation write approval |

## Step 3: Choose Model Family

### A. Image-First or Multimodal Tasks

Prefer a multimodal model such as `MIMO V2.5`.

Use this lane when the task depends on seeing rather than only reading text:

- screenshot understanding
- image comparison
- UI visual audit
- OCR-like extraction from images
- diagram or layout interpretation
- multimodal evidence collection

Rule: do not route image-first tasks to a text-only DeepSeek worker when visual understanding is central to correctness.

### B. Text-Only Collection and Quick Organization

Prefer `DeepSeek V4 Flash`.

Use this lane for:

- public web research
- text data collection
- quick clustering and summarization
- first-pass repository scanning
- structured note taking

Reason: this is the default cheap-and-fast worker lane.

### C. Deeper Analysis and Harder Synthesis

Prefer `DeepSeek V4 Pro`.

Use this lane for:

- harder root-cause analysis
- multi-file reasoning with tradeoffs
- deeper code review
- large-log diagnosis where pattern quality matters
- research that needs stronger synthesis, not just collection

Reason: use the stronger model when the main difficulty is reasoning depth, not document hauling.

### D. Smoke Tests and Cheapest Chain Validation

Prefer `flash-free`.

Use this lane for:

- test the bridge
- validate a prompt format
- confirm task wiring
- run low-stakes trial collection before upgrading the model

Reason: this is the cheapest path for workflow validation.

## Step 4: Codex Review Policy

OpenCode should return compact evidence and a conclusion-first `result.md`.

Codex then:

1. checks whether the worker stayed inside scope
2. verifies important claims when needed
3. rejects weak evidence or overreach
4. gives the final answer to the user

## Default Verbal Commands

The user can assign work with short phrases such as:

- `这个任务按小任务处理`
- `这个任务丢给 sidecar，用便宜模型先搜资料`
- `这个任务交给 sidecar，用 pro 模型做深一点的分析`
- `这个任务是图片相关，走多模态模型`
- `先让 opencode 整理材料，你再做最终判断`

## Fallback Rule

If the preferred model family is not configured yet:

1. keep the same routing intent
2. pick the closest allowed configured model
3. say clearly that the model is a fallback, not the ideal target

Example:

- intended lane: `MIMO V2.5` for screenshot understanding
- current fallback: keep the task in Codex or use another available multimodal tool until `MIMO` is added to the bridge
