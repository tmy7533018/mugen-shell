{
  description = "mugen-shell — a Quickshell + Hyprland desktop with a 夢幻 aesthetic, plus the mugen-ai assistant backend";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    { self, nixpkgs, flake-utils, home-manager }:
    let
      # The home-manager module defaults to `pkgs.mugen-shell`, which only
      # resolves once this overlay is applied.
      overlay = final: prev: {
        mugen-ai = self.packages.${prev.system}.mugen-ai;
        mugen-audio = self.packages.${prev.system}.mugen-audio;
        mugen-shell = self.packages.${prev.system}.mugen-shell;
      };

      nixosModule =
        { ... }:
        {
          imports = [ ./nixos/module.nix ];
          nixpkgs.overlays = [ overlay ];
        };
    in
    {
      overlays.default = overlay;

      homeManagerModules.default = ./nix/home-manager.nix;
      homeManagerModules.mugen-shell = ./nix/home-manager.nix;

      nixosModules.default = nixosModule;
      nixosModules.mugen-shell = nixosModule;

      # Build-only scaffold, never a real host: it exists so eval/type errors
      # in module.nix surface in CI rather than on someone's machine.
      nixosConfigurations.smoke = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          nixosModule
          ({ pkgs, ... }: {
            programs.mugen-shell.enable = true;

            # Bare minimum to make a NixOS config evaluate.
            boot.loader.grub.device = "nodev";
            fileSystems."/" = { device = "/dev/null"; fsType = "tmpfs"; };
            users.users.test = {
              isNormalUser = true;
              home = "/home/test";
            };
            system.stateVersion = "25.05";
          })
        ];
      };

      nixosConfigurations.vm = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          nixosModule
          home-manager.nixosModules.home-manager
          ./nixos/vm.nix
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.users.mugen = { lib, ... }: {
              imports = [ self.homeManagerModules.default ];
              programs.mugen-shell = {
                enable = true;
                # module.nix already installs the stack system-wide.
                includeSystemDeps = false;
              };
              home.stateVersion = "25.05";

              # Seeded per file: the shell creates the wallpaper directory itself.
              home.activation.vmDemoDefaults =
                lib.hm.dag.entryAfter [ "installMugenSystemDefaults" ] ''
                  wallpaper="$HOME/.local/share/mugen-shell/wallpapers/desert-sunset.jpg"
                  if [[ ! -e "$wallpaper" ]]; then
                    mkdir -p "$(dirname "$wallpaper")"
                    install -m 644 ${./nixos/assets/desert-sunset.jpg} "$wallpaper"
                  fi

                  overrides="$HOME/.config/hypr/configs/user-overrides.lua"
                  if [[ ! -e "$overrides" ]]; then
                    mkdir -p "$(dirname "$overrides")"
                    install -m 644 ${./nixos/assets/vm-user-overrides.lua} "$overrides"
                  fi
                '';
            };
          }
        ];
      };
    }
    // flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
      in
      {
        # SETUP's Path B reaches no other output, so nothing else would notice it breaking.
        checks = nixpkgs.lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux {
          home-manager = (home-manager.lib.homeManagerConfiguration {
            pkgs = import nixpkgs {
              inherit system;
              overlays = [ overlay ];
            };
            modules = [
              self.homeManagerModules.default
              {
                home.username = "check";
                home.homeDirectory = "/home/check";
                programs.mugen-shell.enable = true;
                programs.mugen-shell.includeSystemDeps = false;
                home.stateVersion = "26.05";
              }
            ];
          }).activationPackage;
        };

        packages = rec {
          mugen-ai = pkgs.buildGoModule {
            pname = "mugen-ai";
            version = "0.1.0";
            src = ./ai;
            vendorHash = "sha256-Bf6NpGE1lub1IR1hAL+ZdFgnUmJeb3m0UdYMg2cfgCk=";
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

          # Separate so mugen-shell stays a plain copy that needs no build step.
          mugen-audio = pkgs.stdenv.mkDerivation {
            pname = "mugen-audio";
            version = "0.1.0";
            src = ./plugin;
            nativeBuildInputs = with pkgs; [
              cmake
              ninja
              pkg-config
              qt6.wrapQtAppsHook
            ];
            buildInputs = with pkgs; [
              qt6.qtbase
              qt6.qtdeclarative
              libcava
            ];
            meta = {
              description = "Qt QML module exposing libcava's spectrum to mugen-shell";
              homepage = "https://github.com/tmy7533018/mugen-shell";
              license = pkgs.lib.licenses.mit;
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
