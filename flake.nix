{
  description = "mugen-shell — a Quickshell + Hyprland desktop with a 夢幻 aesthetic, plus the mugen-ai assistant backend";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    { self, nixpkgs, flake-utils }:
    let
      # The home-manager module defaults to `pkgs.mugen-shell`, which only
      # resolves once this overlay is applied.
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
            # Ship the config templates so Nix users get the schemas without
            # cloning the repo.
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

          # hypr/ is exposed so users with their own Hyprland config can grab
          # the autostart snippet, in either config language, via
          # `$(nix path-info .#mugen-shell)/hypr/configs/...`.
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
            cp ${./system/hypr/configs/mugen-shell.lua} $out/hypr/configs/mugen-shell.lua
            # Voice daemon runtime, so the service works without a checkout.
            # yura/ is the pipeline itself — yurad.py is only its entry point
            # and imports from it, so shipping the one file crashes on start.
            # tests/ stays out — it does not run at runtime.
            mkdir -p $out/voice
            cp ${./voice/yurad.py} $out/voice/yurad.py
            cp -r ${./voice/yura} $out/voice/yura
          '';

          default = mugen-shell;
        };
      }
    );
}
