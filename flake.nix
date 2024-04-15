{
  inputs = {
    nixpkgs.url = "nixpkgs/nixos-unstable";
    parts.url = "github:hercules-ci/flake-parts";
    pre-commit-hooks = {
      inputs.nixpkgs.follows = "nixpkgs";
      url = "github:cachix/pre-commit-hooks.nix";
    };
  };
  outputs = inputs:
    inputs.parts.lib.mkFlake {inherit inputs;} {
      imports = [inputs.pre-commit-hooks.flakeModule];
      perSystem = {
        config,
        pkgs,
        self',
        ...
      }: let
        inherit (self'.packages) go;
        inherit (self'.legacyPackages) buildGoModule;
      in {
        devShells.default = pkgs.mkShell {
          shellHook = "${config.pre-commit.installationScript}";
        };
        legacyPackages.buildGoModule = pkgs.callPackage "${inputs.nixpkgs}/pkgs/build-support/go/module.nix" {
          inherit go;
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
            runtimeInputs = [go pkgs.golangci-lint];
            text = ''exec golangci-lint "$@"'';
          };
          gopls = pkgs.callPackage "${inputs.nixpkgs}/pkgs/development/tools/language-servers/gopls" {
            inherit buildGoModule;
          };
        };
        pre-commit = {
          settings = {
            hooks = {
              alejandra.enable = true;
              deadnix.enable = true;
              statix.enable = true;
            };
            src = ./.;
          };
        };
      };
      systems = ["aarch64-darwin" "aarch64-linux" "x86_64-darwin" "x86_64-linux"];
    };
}
