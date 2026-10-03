# OpenCode sandbox

OpenCode runs in a bubblewrap sandbox (agent-sandbox) under a root-owned
managed policy. Filesystem and network isolation are the boundary; the policy
shapes behaviour, it is not the boundary.

## Hardening

- **Filesystem** — only the workspace and declared dirs are mounted; `$HOME`
  and `/tmp` are tmpfs; the config dir is read-only.
- **Packages** — gitMinimal + coreutils tools only. No python/perl/curl/node,
  so no scripting runtime or network CLI to weaponise.
- **Network** — filtering proxy with an `allowedDomains` allowlist (provider,
  GitHub, npm, PyPI, crates.io, Nix cache). Web search via Exa MCP.
  `internet = "open"` drops the allowlist.
- **Secrets** — API key injected from sops into env at launch, never in the
  store. Policy denies env/secret reads, `subagent`, `external_directory`.
- **Policy** — shell, search, and fetch ask by default; read-only inspection
  allowed; provider pinned to `opencode-go`.
- **Fail-closed** — the wrapper refuses to launch if the policy/key is
  missing, invalid, or missing sentinel rules.

## Trade-offs

- **Key in env** — the agent can read `$OPENCODE_API_KEY`. Safe only while
  egress is restricted (no attacker-controlled host is reachable). Secret
  masking is deferred: upstream rejected a substitution design (a phantom can
  be exfiltrated) and injection needs a fork.
- **No command bans** — name-based shell denies are bypassable, so the sandbox
  view and proxy are the real controls; shell still asks by default.
- **Single provider** — `opencode-go` only.
