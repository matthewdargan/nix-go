{
  inputs = {
    nixpkgs.url = "nixpkgs/nixos-unstable";
    parts.url = "github:hercules-ci/flake-parts";
  };
  outputs = inputs:
    inputs.parts.lib.mkFlake {inherit inputs;} {
      perSystem = {pkgs, self', ...}: {
        packages = {
          go = pkgs.go.overrideAttrs (_: rec {
            src = pkgs.fetchurl {
              hash = "sha256-N06oKyiexzjpaCZ8rFnH1f8YD5SSJQJUeEsgROkN9ak=";
              url = "https://go.dev/dl/go${version}.src.tar.gz";
            };
            version = "1.22.2";
          });
          golangci-lint = pkgs.writeShellApplication {
            name = "golangci-lint";
            runtimeInputs = [self'.packages.go pkgs.golangci-lint];
            text = ''exec golangci-lint "$@"'';
          };
        };
      };
      systems = ["aarch64-darwin" "aarch64-linux" "x86_64-darwin" "x86_64-linux"];
    };
}
