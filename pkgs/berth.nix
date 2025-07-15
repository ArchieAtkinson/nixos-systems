{ pkgs }:

pkgs.rustPlatform.buildRustPackage {
  pname = "berth";
  version = "6c9884a2605bdd32eef0e8b67ac99262c3417763";

  src = pkgs.fetchFromGitHub {
    owner = "ArchieAtkinson";
    repo = "berth";
    rev = "6c9884a2605bdd32eef0e8b67ac99262c3417763";
    sha256 = "sha256-BvUUKtZjIq4WVBJhyyb0jcBw9C/G1j1YebTh55wuESk=";
  };
  doCheck = false;
  cargoHash = "sha256-60yUTXTWk3x7Ua+W8kO/4SniW07VGlDDVijKChHK01Y=";
}

