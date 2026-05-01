{
  description = "mugen-shell — a Quickshell + Hyprland desktop with a 夢幻 aesthetic, plus the mugen-ai assistant backend";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (
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
          default = mugen-ai;
        };
      }
    );
}
