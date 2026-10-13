{ pkgs, lib, ... }:

let
  localPackagesDir = ./.;
  dirContents = builtins.readDir localPackagesDir;

  allImportedPkgs = lib.mapAttrs (name: type:
    if type == "regular" && lib.hasSuffix ".nix" name && name != "default.nix" then
      let
        attrName = lib.removeSuffix ".nix" name;
      in
      { "${attrName}" = pkgs.callPackage (localPackagesDir + "/${name}") {}; }
    else
      null
  ) dirContents;

  importedLocalPkgs = lib.mergeAttrsList (lib.filter (x: x != null) (lib.attrValues allImportedPkgs));

in
final : prev: {
  local = importedLocalPkgs;
}
