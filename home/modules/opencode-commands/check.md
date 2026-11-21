---
description: Run the project's check suite once
agent: build
---

Run the project's full local check suite once for the current change set —
`just preflight`, `just ci`, `nix flake check`, or whatever the repo defines.

Report the exact command and its result. Fix failures the change caused; report
pre-existing failures instead of fixing them unasked. Do not re-run a check
whose inputs did not change.

$ARGUMENTS
