# OpenCode Flow Improvement — Analysis & Handoff

- **Date:** 2026-11-19
- **Scope:** 156 OpenCode sessions, 2026-10-02 → 2026-11-19
- **Data source:** read-only copies of `~/.local/share/opencode/opencode.db` (+ WAL/SHM)
- **Extracted artifacts:** `/tmp/opencode/session-analysis/extracted/`
- **Scripts:** `~/.local/share/opencode/.session-analysis/extract.py`, `~/.local/share/opencode/.session-analysis/analyze.py`
- **Baseline data:** `~/.local/share/opencode/opencode-flow-baseline.json`

---

## 1. Method and caveats

- The live database was copied to `/tmp` before inspection; the original was never opened read-write.
- `extract.py` exports per-session Markdown transcripts, full JSONL message logs, `sessions.csv`, and `sessions.jsonl`.
- `analyze.py` computes agent outcomes, task-shape metrics, shell intent clustering, frustration scoring, model comparison, and interruption stats.
- Task-shape and shell-intent labels are keyword heuristics.
- Per-model samples are small (2–15 sessions); treat model conclusions as directional.
- 35 sessions from Oct 2 are sandbox probes (`"Reply with exactly: SANDBOX-OK"`), which inflate session counts and pull medians down.
- Cost is as recorded in the DB; free-tier sessions show `$0`.

---

## 2. Baseline metrics

Record these for comparison after future workflow changes.

| Metric | Baseline |
|---|---|
| Sessions | 156 (145 top-level, 11 subagent) |
| Messages | 21,774 (1,372 user, 17,649 assistant, 1,328 idle, 615 synthetic) |
| Tool calls | 19,182 |
| Tool errors | 607 (3.2%) |
| Total cost | $25.06 |
| Median user messages / top-level session | 3 |
| Agent switches | 465 across 68 sessions (max 46 in one) |
| Go/continue nudges | 197 in 57 sessions (49 directly after a stopped turn) |
| Compactions | 11 across 10 sessions |
| Edit error rate | 5.5% (292 / 5,332) |
| webfetch error rate | 26.6% (82 / 308) |
| Shell inspection share | 35.5% (3,325 / 9,363) |
| Cost / session | $0.161 |
| Cache-read tokens | 3,885,343,454 |

### Tool usage and error rate

| Tool | Calls | Errors | Error rate |
|---|---:|---:|---:|
| shell | 9,363 | 124 | 1.3% |
| edit | 5,332 | 292 | 5.5% |
| read | 2,512 | 30 | 1.2% |
| write | 732 | 24 | 3.3% |
| webfetch | 308 | 82 | 26.6% |
| grep | 292 | 3 | 1.0% |
| execute | 210 | 1 | 0.5% |
| websearch | 203 | 14 | 6.9% |
| glob | 114 | 11 | 9.6% |
| question | 71 | 6 | 8.5% |
| subagent | 16 | 5 | 31.2% |
| skill | 14 | 0 | 0% |
| bash | 8 | 8 | 100% |

The `bash`, `python`, `analysis`, and `fetch` entries are non-existent tool names the model invented; they fail immediately.

### Agent / mode outcomes

| Agent | User prompts | Assistant turns | Tool calls | Tool errors | Error turns | Go after stop | Negative prompts |
|---|---:|---:|---:|---:|---:|---:|---:|
| build | 730 | 14,764 | 16,119 | 462 | 137 | 39 | 58 |
| plan | 599 | 2,445 | 2,505 | 88 | 57 | 10 | 65 |
| reviewer | 8 | 242 | 311 | 37 | 2 | 0 | 6 |
| researcher | 2 | 54 | 86 | 3 | 0 | 0 | 0 |
| explore | 1 | 56 | 67 | 6 | 0 | 0 | 1 |
| discussion | 1 | 5 | 14 | 0 | 0 | 0 | 0 |

Build is where the work and the errors live. Plan is comparatively cheap.

### Session shape by task type

| Type | Sessions | Median user msgs | Median tools | Median switches | Median cost | Success | Single-shot |
|---|---:|---:|---:|---:|---:|---:|---:|
| review/audit | 48 | 5 | 102 | 1 | $0.0209 | 87.5% | 8 |
| other (mostly probes) | 30 | 1 | 0 | 0 | $0.0001 | 76.7% | 25 |
| question/discussion | 17 | 2 | 17 | 0 | $0.0024 | 94.1% | 8 |
| plan/design | 17 | 13 | 204 | 3 | $0.1092 | 82.4% | 1 |
| build/implement | 16 | 2 | 10.5 | 0 | $0.0196 | 75.0% | 7 |
| debug/fix | 12 | 3.5 | 19 | 0 | $0.003 | 91.7% | 5 |
| git/worktree | 5 | 13 | 270 | 8 | $0.1745 | 80.0% | 1 |

Success = at least one `idle:succeeded` and no `idle:failed`.

### Frustration ranking (top 10)

Score weights: go-nudge ×2, repeated prompt ×2, compaction ×2, mode switch ×0.5, aborted tool ×1, plan-write block ×1, negative wording ×1, prompt after error ×1, 0.1 × tool errors.

| Score | User msgs | Tools | Cost | Session | Main signals |
|---:|---:|---:|---:|---|---|
| 73.2 | 82 | 209 | $0.00 | Deterministic Rust workspace… | 18 go, 46 switches, 7 negative, 4 plan-write blocks |
| 60.2 | 74 | 221 | $0.00 | Frame rate inquiry | 11 go, 29 switches, 8 negative, 7 after-error |
| 59.4 | 58 | 373 | $1.09 | Reset session1 worktree… | 13 go, 18 switches, 15 after-error |
| 56.0 | 53 | 1,159 | $1.82 | Planning next steps | 10 go, 23 switches, compaction |
| 55.6 | 72 | 1,191 | $3.08 | Create session3 worktree… | 9 go, 19 switches, 15 after-error, compaction |
| 50.3 | 41 | 321 | $0.02 | High-level code review… | 12 go, 26 switches |
| 50.2 | 63 | 752 | $2.91 | Designing whole-game AI testing… | 6 go, 21 switches, 4 aborts, compaction |
| 44.1 | 29 | 1,110 | $0.20 | Create worktree in `.worktree`… | 8 go, 15 switches, compaction |
| 38.3 | 31 | 1,270 | $2.06 | Tidyup branch structure… | 8 go, 13 switches, 2 compactions |
| 38.1 | 25 | 235 | $0.02 | High-level code review (2) | 9 go, 18 switches |

The frustration pattern is almost entirely the mega game-dev sessions: many user turns, mode switches, compactions, and plan-mode write blocks. Sessions created after the new flow no longer look like this.

---

## 3. Decision log — what changed and why

### P1 — Mode separation: keep as-is (closed)

Historical pain was 465 plan↔build switches across 68 sessions, but that predates the new flow. The 16 sessions since Nov 12 show:

- a maximum of 20 user messages (vs 82 previously),
- no mega-sessions,
- clean plan/build separation already reflected in the DB,
- small median session size.

**Decision:** keep the current `discussion` / `plan` / `build` / `pair` split. No further action.

### P2 — Aborts: no action (closed)

49 aborted/declined tool calls total: shell 36, question 5, websearch 3, edit 2, grep 1, execute 1, write 1. This matches the sandbox/laptop-close behavior described, not a workflow defect.

### P3 — Tool discipline: implement (agreed)

Problems:

1. **Shell used for inspection.** 3,325 shell calls (35.5%) were `cat`/`head`/`tail`/`sed -n`/`grep`/`find`/`ls` work that `read`/`grep`/`glob` handle with less context and fewer tokens. Inside shell, `grep` appeared 3,095 times, `head` 3,217, `tail` 2,296, `cat` 827.
2. **Scripted edits bypass edit tooling.** 943 shell calls used Python heredocs to rewrite files (`write_text`, `open(...,'w')`), which hides diffs and encourages stale-state edits.
3. **Repeated verification commands.** `git status --short` ×45, `git status --short --branch` ×25, `cargo fmt --all` ×43, `just ci` ×43, `cargo clippy --workspace --all-targets -- -D warnings` ×29, `cargo check -p walker-core --all-targets` ×28, `cargo build … | tail` ×30.
4. **Edit churn.** 292 edit errors: 228 stale `oldString`, 33 no-op (`old == new`), 10 ambiguous matches, 7 plan-mode blocks, 7 file-not-found.
5. **Web guessing.** 82 webfetch errors: 25 are 404s against guessed `raw.githubusercontent.com` URLs; 16 are policy blocks; the rest are 403s from sites that block fetches.

Recommended AGENTS.md additions:

```md
## Tool discipline
- Inspect files with `read`, `grep`, and `glob`. Do not use shell `cat`, `head`, `tail`, `sed -n`, `ls`, or `find` for inspection.
- Use `edit`/`write` for file changes. Do not rewrite files through shell Python heredocs or `sed -i`.
- Run the project check once at the end of a change set (`just ci` or `just preflight`), not after every small edit.
- Before retrying a failed edit, re-read the target region. Never call `edit` with identical `oldString` and `newString`.
- Prefer project search tools before guessing raw URLs. Treat policy-blocked URLs as unavailable; do not retry them.
```

Suggested `just` recipe (adapt to the repo):

```just
# Run the full local check suite once.
preflight:
    cargo fmt --all --check
    cargo clippy --workspace --all-targets -- -D warnings
    cargo test --workspace
```

### P4 — Model pricing and routing: update routing

Live `opencode-go` pricing checked 2026-11-19 (USD per million tokens):

| Model | Input | Output | Cache read | Notes |
|---|---:|---:|---:|---|
| deepseek-v4.1-flash | 0.15 | 0.60 | **0.003** | Current build default; cheapest cache reads |
| gpt-6-luna | 0.10 | 0.50 | 0.01 | Current pair/discussion; 272k tier doubles input |
| glm-5.3-flash | 0.15 | 0.50 | 0.03 | Cheap plan model |
| glm-5.3 | 1.40 | 4.40 | 0.26 | ~9× glm-flash; avoid unless needed |
| muse-spark-1.3 | 0.10 | **0.20** | 0.002 | Cheapest paid output; 100% success in 7 sessions |
| minimax-m3.1-flash | 0.15 | 0.60 | 0.015 | Mid |
| mimo-v2.6-flash | 0.14 | 0.28 | 0.0028 | Cheap output |
| claude-haiku-5.5 | 0.10 | 0.50 | 0.01 | 100k tier: 0.50 / 2.50 / 0.05 |
| qwen3.8-flash | 0.15 | 0.47 | 0.016 | Mid |
| deepseek-v4-pro | 0.66 | 1.98 | 0.022 | ~4× flash |
| kimi-k2.7-code | 0.95 | 4.00 | 0.19 | Expensive |
| beam-free, hy4-flash-free, longcat-2.5-free, iceman-contributor-free | 0 | 0 | 0 | Free |

Observed reliability on build/debug/review sessions:

| Model | Sessions | Edit error rate | Cost/session | Success |
|---|---:|---:|---:|---:|
| beam-free#max | 15 | **13.8%** | $0.002 | 80% |
| deepseek-v4.1-flash#high | 14 | **2.0%** | $0.269 | 85.7% |
| deepseek-v4.1-flash#low | 9 | 4.8% | $0.12 | 88.9% |
| muse-spark#medium | 7 | 4.0% | $0.37 | 100% |
| muse-spark#high | 5 | 7.1% | $0.048 | 80% |
| muse-spark#low | 4 | 5.3% | $0.197 | 75% |
| glm-5.3-flash#max | 2 | 2.3% | $0.99 | 50% |
| deepseek-v4.1-flash (base) | 2 | 11.1% | $0.20 | 100% |

**Recommendation:**

- Build default: `deepseek-v4.1-flash#low` for routine edits; `#high` for complex refactors and reviews.
- Pair/discussion: keep GPT-6 Luna.
- Plan: keep GLM-Flash, not full GLM-5.3.
- Trial `muse-spark-1.3#medium` as a build loop alternative for one week; compare edit errors and prompts-per-task.
- Never use beam-free for edit-heavy work; restrict it to read-only exploration and summarization.
- Avoid `glm-5.3` full unless its quality gap justifies ~9× cost.
- Cache-read pricing makes long, cache-heavy sessions cheap; do not over-optimize input counts.

### P5 — Compaction and session length: adopt policy

OpenCode V2 supports:

```jsonc
{
  "$schema": "https://opencode.ai/config.json",
  "compaction": {
    "auto": true,
    "background": true,
    "keep": { "tokens": 24000 },
    "buffer": "20%"
  },
  "agents": {
    "compaction": { "model": "opencode-go/deepseek-v4.1-flash#low" }
  }
}
```

- `buffer: "20%"` compacts earlier (default ~15%, minimum 16k).
- `keep.tokens: 24000` preserves more exact recent detail (default 15k).
- `agents.compaction.model` lets a cheap model write summaries.
- Manual compaction: `opencode api post /api/session/<session-id>/compact --data '{}'`.
- Automatic compaction cannot be replaced with a hard "max messages" limit; no such setting exists.

Advisory policy for AGENTS.md:

```md
## Session hygiene
- At the first compaction, or around 30 user turns, stop expanding scope.
- Write a short handoff summary: Objective, Decisions, Completed, Next Move, Relevant files.
- Recommend starting a fresh session from that summary. Do not continue a mega-session by default.
```

Optional, only if the advisory is ignored: a small plugin that warns at N user turns. Prefer the instruction first.

---

## 4. Anything else worth analysing

1. **Validate the new flow with a pre/post split.** Once there are 20+ sessions after Nov 12, rerun the scripts and compare switches/session, go-rate, median user turns, and compactions.
2. **Build a prompt library.** Repeated review prompts (the Rust three-reviewer prompt ×4, "critically review these changes" ×6) should become `/commands`, not retyped.
3. **Review the sandbox allowlist.** 84 shell calls were blocked by policy. Most were intentional security probes, but `just ci` and config-file reads were blocked once each — check whether these belong in the allowlist.
4. **Per-project breakdown.** Early grouping showed most cost/tool usage in `/home/archie/repos` (walker/tui-game). Split future analysis by repo for targeted AGENTS.md files.
5. **Subagent depth.** 5 subagent calls failed on depth limit; if nested review is intended, raise `experimental.subagent_depth`, otherwise keep reviews one level deep.

---

## 5. Measurement plan

Re-run monthly or after major workflow changes:

```sh
cp ~/.local/share/opencode/opencode.db* /tmp/opencode/session-analysis/
python3 ~/.local/share/opencode/.session-analysis/extract.py
python3 ~/.local/share/opencode/.session-analysis/analyze.py
```

Track these KPIs:

| KPI | Baseline | Target |
|---|---:|---:|
| Agent switches / session | 2.98 avg | <1 median, <5 p90 |
| Go-nudges / session | 1.26 | <0.3 |
| Edit error rate | 5.5% | <3% |
| webfetch error rate | 26.6% | <10% |
| Shell inspection share | 35.5% | <15% |
| Compaction sessions | 6.4% | <3% |
| Cost / active session | $0.16 | ≤ baseline |
| Median user msgs / task | 3 | ≤ 3 |

---

## 6. Exact handoff instructions for the system agent

1. **Do not change** the `discussion` / `plan` / `build` / `pair` separation or the mode-switch behavior. P1 is closed.
2. **Do not change** abort handling or sandbox behavior for laptop-close. P2 is closed.
3. **Update AGENTS.md** with the Tool discipline, Edit reliability, Web, and Session hygiene blocks above.
4. **Add `just preflight`** to touched repos (or standardize on existing `just ci`) and instruct agents to run it once per change set.
5. **Update model routing:** keep deepseek-v4.1-flash for build (low/high split), GPT-6 Luna for pair/discussion, GLM-Flash for plan; trial muse-spark medium; forbid beam-free for edit-heavy tasks.
6. **Update compaction config:** buffer 20%, keep.tokens 24000, cheap compaction model.
7. **Add commands** for `/check` (run preflight), `/handoff` (structured summary), and convert repeated review prompts into `/review` variants.
8. **Re-run the analysis** after ~20 new-flow sessions and compare against the baseline table above. Keep the why (this document) with the results.
