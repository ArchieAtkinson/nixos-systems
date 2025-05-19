{ pkgs }:

pkgs.rustPlatform.buildRustPackage {
  pname = "todui";
  version = "eb117dc9c06866fb23c64f544ad423cf48e3142e";

  src = pkgs.fetchFromGitHub {
    owner = "danimelchor";
    repo = "todui";
    rev = "eb117dc9c06866fb23c64f544ad423cf48e3142e";
    sha256 = "sha256-MFo4E/wrCxNqQhMtjjPjJ9GJUZ9sOMn2jy5cNO5gQec=";
  };
  cargoHash = "sha256-r0cMO0Ss1ky3dcczU9EozYttbK5JQED9hxHSzFd9V1s=";
}

