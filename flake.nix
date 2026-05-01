{
  description = "mugen-shell — a Quickshell + Hyprland desktop with a 夢幻 aesthetic, plus the mugen-ai assistant backend";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    { self, nixpkgs, flake-utils }:
    let
      # Overlay that exposes mugen-ai and mugen-shell as pkgs.<name>, so the
      # home-manager module can refer to them as defaults via `pkgs.mugen-shell`.
      overlay = final: prev: {
        mugen-ai = self.packages.${prev.system}.mugen-ai;
        mugen-shell = self.packages.${prev.system}.mugen-shell;
      };
    in
    {
      overlays.default = overlay;

      homeManagerModules.default = ./nix/home-manager.nix;
      homeManagerModules.mugen-shell = ./nix/home-manager.nix;
    }
    // flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
      in
      {
        packages = rec {
          mugen-ai = pkgs.buildGoModule {
            pname = "mugen-ai";
            version = "0.1.0";
            src = ./ai;
            vendorHash = "sha256-n58Qmiv3gik1qkuXQFbQ+soeOQtUz1dUocEAJepqp/E=";
            meta = {
              description = "AI backend service for mugen-shell";
              homepage = "https://github.com/tmy7533018/mugen-shell";
              license = pkgs.lib.licenses.mit;
              mainProgram = "mugen-ai";
            };
          };

          # The Quickshell QML tree (UI code, scripts, assets, default
          # settings). No build step — just gets copied into the Nix
          # store so home-manager can symlink the result into
          # ~/.config/quickshell/mugen-shell.
          mugen-shell = pkgs.runCommand "mugen-shell-0.1.0" {
            meta = {
              description = "Quickshell desktop UI for mugen-shell";
              homepage = "https://github.com/tmy7533018/mugen-shell";
              license = pkgs.lib.licenses.mit;
            };
          } ''
            mkdir -p $out
            cp -r ${./shell}/. $out/
          '';

          default = mugen-shell;
        };
      }
    );
}
