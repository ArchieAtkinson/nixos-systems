---
description: Review the current diff
agent: reviewer
subagent: true
---

Use the code-review skill to review these changes (staged, unstaged, and untracked
files listed by status):

!`git status --short && git diff HEAD`

If there is no uncommitted change, say so and ask which commit or branch to
review instead.
