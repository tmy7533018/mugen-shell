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
            vendorHash = "sha256-n4brPv9eZJPqdTvnjdqQK7Q8JVgZvJbD5ndKFQEfu0I=";
            # Annotated templates so Nix-installed users can find the .env
            # and config.toml schemas without cloning the repo.
            postInstall = ''
              mkdir -p $out/share/mugen-ai
              cp .env.example config.toml.example $out/share/mugen-ai/
            '';
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
          # ~/.config/quickshell/mugen-shell. The hypr/ snippet is also
          # exposed so users with their own hyprland.conf can grab it
          # via `$(nix path-info .#mugen-shell)/hypr/configs/...`.
          mugen-shell = pkgs.runCommand "mugen-shell-0.1.0" {
            meta = {
              description = "Quickshell desktop UI for mugen-shell";
              homepage = "https://github.com/tmy7533018/mugen-shell";
              license = pkgs.lib.licenses.mit;
            };
          } ''
            mkdir -p $out
            cp -r ${./shell}/. $out/
            mkdir -p $out/hypr/configs
            cp ${./system/hypr/configs/mugen-shell.conf} $out/hypr/configs/mugen-shell.conf
            # Voice daemon runtime, so the service works without a checkout.
            # train/ stays out — it is a separate pipeline, not runtime.
            mkdir -p $out/voice/models
            cp ${./voice/yurad.py} $out/voice/yurad.py
            cp -r ${./voice/models}/. $out/voice/models/
          '';

          default = mugen-shell;
        };
      }
    );
}
