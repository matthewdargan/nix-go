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
              hash = "sha256-gkTr9GxlYH2xAiK1gGrrMcH8+JecG2sS9gxnfpo8BlY=";
              url = "https://go.dev/dl/go${version}.src.tar.gz";
            };
            version = "1.24.1";
          });
          goVersion = pkgs.writeShellApplication {
            name = "go-version";
            runtimeInputs = [
              pkgs.coreutils
              pkgs.curl
              pkgs.gh
              pkgs.git
              pkgs.gnugrep
              pkgs.gnused
              pkgs.jq
            ];
            text = ''
              set -eux
              v1="$(curl -s 'https://go.dev/dl/?mode=json' | jq -r '.[].version' | sort -r | head -n 1 | tr -d '[:alpha:]')"
              v2="$(grep -Eo '[0-9]+\.[0-9]+\.[0-9]+' flake.nix)"
              if [[ "''${v1}" == "''${v2}" ]]; then
                exit 0
              fi

              nix flake update
              sed -i "s/version = \"''${v2}\"/version = \"''${v1}\"/" flake.nix
              nix_build_output="$(nix build .#go 2>&1 || true)"
              if [[ "''${nix_build_output}" =~ got:[[:space:]]+(sha256-.+=) ]]; then
                hash="''${BASH_REMATCH[1]}"
                sed -i "s#hash = \".*\"#hash = \"''${hash}\"#" flake.nix
              fi

              git config --global user.email 'github-actions[bot]@users.noreply.github.com'
              git config --global user.name 'github-actions[bot]'
              branch="chore/go''${v1}"
              commit="chore: bump Go version to ''${v1}"
              git switch --create "''${branch}"
              git commit -am "''${commit}"
              git push --set-upstream origin "''${branch}"
              gh pr create --assignee matthewdargan --title "''${commit}" --body ''' --head "''${branch}"
            '';
          };
          golangci-lint = pkgs.writeShellApplication {
            name = "golangci-lint";
            runtimeInputs = [go pkgs.golangci-lint];
            text = ''exec golangci-lint "$@"'';
          };
          gopls = pkgs.callPackage "${inputs.nixpkgs}/pkgs/by-name/go/gopls/package.nix" {
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
