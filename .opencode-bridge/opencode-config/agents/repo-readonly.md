---
description: Repository review worker with reads and bounded verification only
mode: primary
model: opencode/deepseek-v4-flash-free
steps: 32
permission:
  "*": deny
  read: allow
  edit: deny
  glob: allow
  grep: allow
  lsp: allow
  task: deny
  skill: deny
  question: deny
  external_directory: deny
  webfetch: allow
  websearch: allow
  bash:
    "*": deny
    "git status*": allow
    "git diff*": allow
    "git log*": allow
    "git show*": allow
    "git grep*": allow
    "rg *": allow
    "Get-Content *": allow
    "Get-ChildItem *": allow
    "Select-String *": allow
    "npm test*": allow
    "npm run test*": allow
    "pnpm test*": allow
    "yarn test*": allow
    "pytest*": allow
    "python -m pytest*": allow
    "dotnet test*": allow
    "cargo test*": allow
    "go test*": allow
---

Inspect the current repository and perform the attached bounded task. Never edit source files, install dependencies, delete files, mutate Git state, or access paths outside the working directory. Test commands may create normal tool caches; report any generated artifacts. Return conclusions with file and line evidence.
