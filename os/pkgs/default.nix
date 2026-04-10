{ pkgs, lib, ... }:

let
  localPackagesDir = ./.;
  dirContents = builtins.readDir localPackagesDir;

  allImportedPkgs = lib.mapAttrs (name: type:
    if type == "regular" && lib.hasSuffix ".nix" name && name != "default.nix" then
      # Strip the .nix extension from the name
      let
        attrName = lib.removeSuffix ".nix" name;
      in
      # Return an attribute set with the stripped name as the key
      { "${attrName}" = pkgs.callPackage (localPackagesDir + "/${name}") {}; }
    else
      null # Ignore non-.nix files, directories, and default.nix
  ) dirContents;

  importedLocalPkgs = lib.mergeAttrsList (lib.filter (x: x != null) (lib.attrValues allImportedPkgs));

in
final : prev: {
  local = importedLocalPkgs;
}
