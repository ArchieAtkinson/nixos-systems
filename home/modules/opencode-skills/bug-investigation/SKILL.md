---
name: Bug investigation
description: Reproduce, isolate, and verify a bug before proposing a fix
---

# Bug investigation

Find the cause before proposing a fix.

## Workflow

1. **Reproduce.** Get a concrete failure: the command, input, and full error.
   If it cannot be reproduced, say so and ask for the missing detail.
2. **Read the actual error.** Read the stack trace, log line, or failing
   assertion — not a paraphrase of it.
3. **Isolate.** Narrow to the smallest unit that still fails: one command, one
   function, one module, one config option.
4. **Hypothesise once at a time.** State the hypothesis, then test it with the
   cheapest read or command. Do not stack hypotheses.
5. **Verify the cause.** Confirm the mechanism explains the symptom before
   writing code. If the fix would be a guess, keep investigating.
6. **Propose the fix** with the file and line that change, and the verification
   that will prove it fixed.

## When blocked

Two failed attempts on the same approach means stop. Report:

- what you expected,
- what actually happened,
- what you tried,
- what you need (a file, a log, a device, host-side access).

Do not silently switch to a different problem, and do not substitute a
reconstructed guess for the missing information.
