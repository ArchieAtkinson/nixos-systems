# Managed OpenCode policy, written to ~/.config/opencode/opencode.json and
# injected as OPENCODE_CONFIG_CONTENT by the wrapper.
#
# Advisory only; the bubblewrap sandbox is the boundary.
{ lib }:
let
  # Auto-allow these fetch hosts; egress is still gated by allowedDomains.
  fetchAllowRules = lib.concatMap (host: [
    {
      action = "webfetch";
      resource = "https://${host}/*";
      effect = "allow";
    }
    {
      action = "webfetch";
      resource = "https://*.${host}/*";
      effect = "allow";
    }
  ]) [
    "wikipedia.org"
    "wikimedia.org"
    "wikidata.org"
    "wiktionary.org"
    "kagi.com"
    "arxiv.org"
    "doi.org"
    "ncbi.nlm.nih.gov"
    "europepmc.org"
    "biorxiv.org"
    "medrxiv.org"
    "nature.com"
    "science.org"
    "link.springer.com"
    "plos.org"
    "openreview.net"
    "semanticscholar.org"
    "zenodo.org"
    "openalex.org"
    "core.ac.uk"
    "ietf.org"
    "rfc-editor.org"
    "w3.org"
    "whatwg.org"
    "unicode.org"
    "iana.org"
    "developer.mozilla.org"
    "docs.python.org"
    "doc.rust-lang.org"
    "docs.rs"
    "go.dev"
    "pkg.go.dev"
    "man7.org"
    "docs.kernel.org"
    "readthedocs.io"
    "readthedocs.org"
    "stackoverflow.com"
    "stackexchange.com"
    "news.ycombinator.com"
    "lobste.rs"
    "web.archive.org"
    "archive.org"
    "gutenberg.org"
    "openlibrary.org"
    "data.gov"
    "who.int"
    "europa.eu"
    "worldbank.org"
    "reuters.com"
    "apnews.com"
    "bbc.co.uk"
    "npr.org"
    "theguardian.com"
    "github.com"
    "githubusercontent.com"
  ];

  # Read-only inspection commands, shared by the global shell rules.
  readOnlyCommands = [
    "git status"
    "git diff"
    "git log"
    "git show"
    "git branch"
    "rg"
    "grep"
    "fd"
    "ls"
    "cat"
    "head"
    "tail"
    "wc"
    "file"
    "stat"
    "du"
    "df"
    "tree"
    "jq"
    "which"
    "type"
    "echo"
    "printf"
    "basename"
    "dirname"
    "realpath"
    "readlink"
    "sort"
    "uniq"
    "cut"
    "tr"
    "diff"
    "date"
    "uname"
  ];

  shellAllow =
    commands:
    map (cmd: {
      action = "shell";
      resource = "${cmd} *";
      effect = "allow";
    }) commands
    ++ [
      {
        action = "shell";
        resource = "pwd";
        effect = "allow";
      }
      {
        action = "shell";
        resource = "id";
        effect = "allow";
      }
    ];

  readOnlyPermissions = shellAllow readOnlyCommands;

  planPermissions = [
    {
      action = "edit";
      resource = "*";
      effect = "deny";
    }
    # keep the built-in plan agent's ability to persist plan files.
    {
      action = "edit";
      resource = "~/.opencode/plan/**";
      effect = "allow";
    }
    {
      action = "shell";
      resource = "*";
      effect = "allow";
    }
  ];
in
{
  "$schema" = "https://opencode.ai/config.json";
  update = "disable";
  share = "disabled";

  # Plugins are resolved at startup and pinned for reproducibility.
  # Context pruning is left to the native compaction settings above.
  plugins = [
    "superpowers@git+https://github.com/obra/superpowers.git#22f0b463e7a5e579904dd6211a520321035526f7"
    "opencode-planning-with-files@1.2.0"
  ];

  default_agent = "build";

  # Compact earlier than default and keep more recent detail verbatim.
  compaction = {
    auto = true;
    background = true;
    keep.tokens = 24000;
    buffer = "20%";
  };

  # Exa hosted MCP, no key.
  websearch = {
    provider = "exa";
  };

  # Primary agents set the session mode; subagents are read-only helpers.
  agents = {
    build = {
      mode = "primary";
      description = "Default implementation agent for repo changes";
      model = "opencode-go/deepseek-v4.1-flash";
    };
    plan = {
      mode = "primary";
      description = "Read-only planning for broad, multi-file work";
      model = "opencode-go/glm-5.3-flash#high";
      color = "#bb9af7";
      system = "Plan-only mode. Explore broadly before concluding: read the relevant modules and trace how a change propagates. Present the target files, approach, risks, and verification steps. Ask when scope is ambiguous. Do not edit files; shell is allowed for inspection and verification.";
      permissions = planPermissions;
    };
    discussion = {
      mode = "primary";
      description = "Quick back-and-forth and rubber-ducking";
      model = "opencode-go/gpt-6-luna#none";
      color = "#9ece6a";
      system = "Discussion mode. Answer in a few sentences with no preamble. Do not edit files or run shell commands; use read-only tools only when a lookup is needed. If the question needs a code change or deep investigation, say so and suggest switching to plan, build, or pair. If the request is unclear, ask immediately instead of guessing.";
      permissions = [
        {
          action = "edit";
          resource = "*";
          effect = "deny";
        }
        {
          action = "shell";
          resource = "*";
          effect = "deny";
        }
      ];
    };
    pair = {
      mode = "primary";
      description = "Pairs on small, fast incremental changes";
      model = "opencode-go/gpt-6-luna#none";
      color = "#ff9e64";
      system = "Pair-programming mode. Work in small coherent steps: make one change, report exactly what changed and how it was checked, then wait for the user's steer before continuing. Do not ask permission for trivial edits; do ask before anything destructive or scope-expanding. If blocked or the approach stops working, stop and report rather than pushing through.";
    };

    researcher = {
      mode = "subagent";
      description = "Reads code and web sources; cannot edit or run shell";
      system = "Research only. Cite sources with URLs. Do not modify files or run shell commands.";
      permissions = [
        {
          action = "edit";
          resource = "*";
          effect = "deny";
        }
        {
          action = "shell";
          resource = "*";
          effect = "deny";
        }
      ];
    };
    reviewer = {
      mode = "subagent";
      description = "Reviews changes without editing";
      model = "opencode-go/glm-5.3#high";
      system = "Review only. Report findings in severity order with file and line references, covering correctness first, then missing tests, security, and project-specific correctness such as Nix conventions. Do not modify files or run shell commands.";
      permissions = [
        {
          action = "edit";
          resource = "*";
          effect = "deny";
        }
        {
          action = "shell";
          resource = "*";
          effect = "deny";
        }
      ];
    };

    # summaries are mechanical; use the cheap model for them.
    compaction = {
      model = "opencode-go/deepseek-v4.1-flash#low";
    };
  };

  permissions = [
    # shell is allowed without prompting; the sandbox is the boundary.
    {
      action = "shell";
      resource = "*";
      effect = "allow";
    }
  ] ++ readOnlyPermissions ++ [
    # fetch and search are allowed without prompting; egress stays filtered.
    {
      action = "webfetch";
      resource = "*";
      effect = "allow";
    }
    {
      action = "websearch";
      resource = "*";
      effect = "allow";
    }

    # subagents: allowed by default, restricted ones denied below.
    {
      action = "subagent";
      resource = "*";
      effect = "allow";
    }
    {
      action = "subagent";
      resource = "explore";
      effect = "allow";
    }
    {
      action = "subagent";
      resource = "researcher";
      effect = "allow";
    }
    {
      action = "subagent";
      resource = "reviewer";
      effect = "allow";
    }
  ] ++ fetchAllowRules;

  experimental.policies = [
    {
      action = "provider.use";
      resource = "*";
      effect = "deny";
    }
    {
      action = "provider.use";
      resource = "opencode-go";
      effect = "allow";
    }

    {
      action = "tool.use";
      resource = "external_directory:*";
      effect = "deny";
    }
    {
      action = "tool.use";
      resource = "subagent:*";
      effect = "deny";
    }
    # ...except the read-oriented subagents (permissions above still apply).
    {
      action = "tool.use";
      resource = "subagent:explore";
      effect = "allow";
    }
    {
      action = "tool.use";
      resource = "subagent:researcher";
      effect = "allow";
    }
    {
      action = "tool.use";
      resource = "subagent:reviewer";
      effect = "allow";
    }

    {
      action = "tool.use";
      resource = "read:*.env";
      effect = "deny";
    }
    {
      action = "tool.use";
      resource = "read:*.env.*";
      effect = "deny";
    }
    {
      action = "tool.use";
      resource = "read:*.env.example";
      effect = "allow";
    }
    {
      action = "tool.use";
      resource = "read:*.pem";
      effect = "deny";
    }
    {
      action = "tool.use";
      resource = "read:*.key";
      effect = "deny";
    }
    {
      action = "tool.use";
      resource = "read:*.sops";
      effect = "deny";
    }
    {
      action = "tool.use";
      resource = "read:*.age";
      effect = "deny";
    }
    {
      action = "tool.use";
      resource = "read:*credentials*";
      effect = "deny";
    }
    {
      action = "tool.use";
      resource = "read:*secret*";
      effect = "deny";
    }
    {
      action = "tool.use";
      resource = "edit:*.env*";
      effect = "deny";
    }
    {
      action = "tool.use";
      resource = "edit:*credentials*";
      effect = "deny";
    }
    {
      action = "tool.use";
      resource = "edit:*secret*";
      effect = "deny";
    }
    {
      action = "tool.use";
      resource = "edit:*.pem";
      effect = "deny";
    }
    {
      action = "tool.use";
      resource = "edit:*.key";
      effect = "deny";
    }
    {
      action = "tool.use";
      resource = "edit:*.sops";
      effect = "deny";
    }
    {
      action = "tool.use";
      resource = "edit:*.age";
      effect = "deny";
    }

    # the key is in env; deny env reads.
    {
      action = "tool.use";
      resource = "shell:env";
      effect = "deny";
    }
    {
      action = "tool.use";
      resource = "shell:env *";
      effect = "deny";
    }
    {
      action = "tool.use";
      resource = "shell:printenv *";
      effect = "deny";
    }
    {
      action = "tool.use";
      resource = "read:/proc/*";
      effect = "deny";
    }
  ];
}
