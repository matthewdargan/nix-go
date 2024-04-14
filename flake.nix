{
  inputs = {
    nixpkgs.url = "nixpkgs/nixos-unstable";
    parts.url = "github:hercules-ci/flake-parts";
  };
  outputs = inputs:
    inputs.parts.lib.mkFlake {inherit inputs;} {
      perSystem = {
        pkgs,
        self',
        ...
      }: {
        legacyPackages.buildGoModule = pkgs.callPackage "${inputs.nixpkgs}/pkgs/build-support/go/module.nix" {
          inherit (self'.packages) go;
        };
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
          gopls = pkgs.callPackage "${inputs.nixpkgs}/pkgs/development/tools/language-servers/gopls" {
            inherit (self'.legacyPackages) buildGoModule;
          };
        };
      };
      systems = ["aarch64-darwin" "aarch64-linux" "x86_64-darwin" "x86_64-linux"];
    };
}
