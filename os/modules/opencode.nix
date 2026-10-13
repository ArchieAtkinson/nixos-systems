{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.modules.opencode;

  # Reads that should not prompt. Egress is still gated by allowedDomains, so
  # this only removes the OpenCode approval step for the curated hosts. The
  # "*" ask rule stays first as the catch-all. Each host gets both its bare and
  # "*.host" form, because the permission `*` does not match the literal dot.
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

  # Injected as OPENCODE_CONFIG_CONTENT.
  managedPolicy = {
    "$schema" = "https://opencode.ai/config.json";
    update = "disable";
    share = "disabled";

    # Exa hosted MCP, no key.
    websearch = {
      provider = "exa";
    };

    # Read-only child agents. Children use their own permissions, not a subset
    # of the parent's, so each is restricted explicitly. Global permission
    # rules (including the webfetch allowlist) still apply.
    agents = {
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
        system = "Review only. Report findings in severity order with file and line references. Do not modify files.";
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
    };

    permissions = [
      # shell asks by default; allow read-only inspection.
      {
        action = "shell";
        resource = "*";
        effect = "ask";
      }
      {
        action = "shell";
        resource = "git status *";
        effect = "allow";
      }
      {
        action = "shell";
        resource = "git diff *";
        effect = "allow";
      }
      {
        action = "shell";
        resource = "git log *";
        effect = "allow";
      }
      {
        action = "shell";
        resource = "git show *";
        effect = "allow";
      }
      {
        action = "shell";
        resource = "git branch *";
        effect = "allow";
      }
      {
        action = "shell";
        resource = "grep *";
        effect = "allow";
      }
      {
        action = "shell";
        resource = "rg *";
        effect = "allow";
      }
      {
        action = "shell";
        resource = "ls *";
        effect = "allow";
      }
      {
        action = "shell";
        resource = "fd *";
        effect = "allow";
      }

      {
        action = "shell";
        resource = "cat *";
        effect = "allow";
      }
      {
        action = "shell";
        resource = "head *";
        effect = "allow";
      }
      {
        action = "shell";
        resource = "tail *";
        effect = "allow";
      }
      {
        action = "shell";
        resource = "wc *";
        effect = "allow";
      }
      {
        action = "shell";
        resource = "file *";
        effect = "allow";
      }
      {
        action = "shell";
        resource = "stat *";
        effect = "allow";
      }
      {
        action = "shell";
        resource = "du *";
        effect = "allow";
      }
      {
        action = "shell";
        resource = "df *";
        effect = "allow";
      }
      {
        action = "shell";
        resource = "tree *";
        effect = "allow";
      }
      {
        action = "shell";
        resource = "jq *";
        effect = "allow";
      }
      {
        action = "shell";
        resource = "which *";
        effect = "allow";
      }
      {
        action = "shell";
        resource = "type *";
        effect = "allow";
      }
      {
        action = "shell";
        resource = "pwd";
        effect = "allow";
      }
      {
        action = "shell";
        resource = "echo *";
        effect = "allow";
      }
      {
        action = "shell";
        resource = "printf *";
        effect = "allow";
      }
      {
        action = "shell";
        resource = "basename *";
        effect = "allow";
      }
      {
        action = "shell";
        resource = "dirname *";
        effect = "allow";
      }
      {
        action = "shell";
        resource = "realpath *";
        effect = "allow";
      }
      {
        action = "shell";
        resource = "readlink *";
        effect = "allow";
      }
      {
        action = "shell";
        resource = "sort *";
        effect = "allow";
      }
      {
        action = "shell";
        resource = "uniq *";
        effect = "allow";
      }
      {
        action = "shell";
        resource = "cut *";
        effect = "allow";
      }
      {
        action = "shell";
        resource = "tr *";
        effect = "allow";
      }
      {
        action = "shell";
        resource = "diff *";
        effect = "allow";
      }
      {
        action = "shell";
        resource = "date *";
        effect = "allow";
      }
      {
        action = "shell";
        resource = "uname *";
        effect = "allow";
      }
      {
        action = "shell";
        resource = "id";
        effect = "allow";
      }

      {
        action = "webfetch";
        resource = "*";
        effect = "ask";
      }
      {
        action = "websearch";
        resource = "*";
        effect = "ask";
      }

      # subagents: ask by default, allow the read-oriented ones.
      {
        action = "subagent";
        resource = "*";
        effect = "ask";
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
      # single allowed provider.
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

      # hard denies.
      {
        action = "permission";
        resource = "external_directory:*";
        effect = "deny";
      }
      {
        action = "permission";
        resource = "subagent:*";
        effect = "deny";
      }
      # ...except the read-oriented subagents. A policy allow only lifts the
      # deny; the permissions above still decide what the child may do.
      {
        action = "permission";
        resource = "subagent:explore";
        effect = "allow";
      }
      {
        action = "permission";
        resource = "subagent:researcher";
        effect = "allow";
      }
      {
        action = "permission";
        resource = "subagent:reviewer";
        effect = "allow";
      }

      # secret material.
      {
        action = "permission";
        resource = "read:*.env";
        effect = "deny";
      }
      {
        action = "permission";
        resource = "read:*.env.*";
        effect = "deny";
      }
      {
        action = "permission";
        resource = "read:*.env.example";
        effect = "allow";
      }
      {
        action = "permission";
        resource = "read:*.pem";
        effect = "deny";
      }
      {
        action = "permission";
        resource = "read:*.key";
        effect = "deny";
      }
      {
        action = "permission";
        resource = "read:*.sops";
        effect = "deny";
      }
      {
        action = "permission";
        resource = "read:*.age";
        effect = "deny";
      }
      {
        action = "permission";
        resource = "read:*credentials*";
        effect = "deny";
      }
      {
        action = "permission";
        resource = "read:*secret*";
        effect = "deny";
      }
      {
        action = "permission";
        resource = "edit:*.env*";
        effect = "deny";
      }
      {
        action = "permission";
        resource = "edit:*credentials*";
        effect = "deny";
      }
      {
        action = "permission";
        resource = "edit:*secret*";
        effect = "deny";
      }
      {
        action = "permission";
        resource = "edit:*.pem";
        effect = "deny";
      }
      {
        action = "permission";
        resource = "edit:*.key";
        effect = "deny";
      }
      {
        action = "permission";
        resource = "edit:*.sops";
        effect = "deny";
      }
      {
        action = "permission";
        resource = "edit:*.age";
        effect = "deny";
      }

      # the key is in env; deny env reads.
      {
        action = "permission";
        resource = "shell:env";
        effect = "deny";
      }
      {
        action = "permission";
        resource = "shell:env *";
        effect = "deny";
      }
      {
        action = "permission";
        resource = "shell:printenv *";
        effect = "deny";
      }
      {
        action = "permission";
        resource = "read:/proc/*";
        effect = "deny";
      }
    ];
  };
in
{
  options.modules.opencode = {
    enable = lib.mkEnableOption "root-owned OpenCode managed policy";
  };

  config = lib.mkIf cfg.enable {
    environment.etc."opencode/opencode.json".text = builtins.toJSON managedPolicy;

    sops.secrets.opencode_go_key = {
      owner = "archie";
      mode = "0400";
    };
  };
}
