---
name: NixOS change
description: Make a scoped NixOS or Home Manager change in this repository
---

# NixOS change

`os/` is the NixOS configuration (system, secrets, udev). `home/` is the
Home Manager configuration (user packages, dotfiles, wrappers, and the OpenCode
policy).

## Workflow

1. **Find the owning module.** Search `os/modules` or `home/modules` for the
   nearest existing implementation before creating anything. A change usually
   belongs in an existing module, not a new one.
2. **Check registration.** Confirm the module is imported where it needs to be
   (`os/flake.nix`, `home/flake.nix`, or a host/config file) and that the host
   actually enables it.
3. **Mirror the neighbours.** Copy the module's argument list, option
   style (`lib.mkEnableOption`, `lib.mkOption`, `config = lib.mkIf ...`), and
   file layout from the closest existing module.
4. **Make the smallest consistent edit.** Keep options declared once, and make
   sure every option added is read somewhere.
5. **State verification for the host.** `nix build` and `nix develop` do not
   work inside this sandbox, so the user runs the switch. End with the exact
   command:

   ```text
   sudo nixos-rebuild switch --flake ./os#<host>
   home-manager switch --flake ./home#<config>
   ```

6. **Report** the files changed, the option or behaviour added, and the switch
   command to run.

## Rules

- Do not edit secrets files or anything matched by the credential denies.
- Do not restructure unrelated modules; keep the diff focused.
- If the change touches the OpenCode policy or sandbox, call it out explicitly —
  the wrapper fails closed and a mistake blocks launch.
