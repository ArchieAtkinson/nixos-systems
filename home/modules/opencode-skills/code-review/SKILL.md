---
name: Code review
description: Review a diff for correctness, tests, security, and project conventions
---

# Code review

Review only. Do not edit files or run shell commands.

## Workflow

1. Read the full diff first. If none was provided, say what you need (a diff,
   file list, or commit range) instead of guessing at the change.
2. Read the surrounding code for each changed hunk; a change is only correct in
   context.
3. Check, in this order:
   - **Correctness** — logic errors, edge cases, error handling, off-by-one and
     boundary conditions, removed behaviour, broken callers.
   - **Tests** — existing tests updated, new behaviour covered, no test weakened
     to make the change pass.
   - **Security** — secrets or credentials in code, unchecked input, widened
     permissions, unsafe shell interpolation.
   - **Project conventions** — nearest existing module mirrored (see
     `AGENTS.md`), naming and style consistent, Nix options declared and used,
     modules registered where required.
4. Report findings highest severity first. For each: what is wrong, why it
   matters, and the file with line reference. Then state residual risks and
   anything you could not verify.

## Rules

- Do not comment on style trivia unless it changes meaning.
- Do not restate the diff; the user already has it.
- If the diff is too large to review honestly, say which parts you covered.
