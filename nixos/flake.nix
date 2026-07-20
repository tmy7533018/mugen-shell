{
  description = "mugen-shell NixOS umbrella — system-level integration on top of the user-level flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # `path:..` resolves to the repo root when this flake is fetched via
    # `?dir=nixos`, which keeps the two layers in lock-step.
    mugen-shell = {
      url = "path:..";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      home-manager,
      mugen-shell,
      ...
    }:
    let
      overlay = mugen-shell.overlays.default;
      nixosModule =
        { ... }:
        {
          imports = [ ./module.nix ];
          nixpkgs.overlays = [ overlay ];
        };
    in
    {
      nixosModules.default = nixosModule;
      nixosModules.mugen-shell = nixosModule;

      # Re-exported so a NixOS user only needs this one flake input.
      inherit (mugen-shell)
        packages
        homeManagerModules
        overlays
        ;

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
          ./vm.nix
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.users.mugen = { lib, ... }: {
              imports = [ mugen-shell.homeManagerModules.default ];
              programs.mugen-shell = {
                enable = true;
                # module.nix already installs the stack system-wide.
                includeSystemDeps = false;
              };
              home.stateVersion = "25.05";

              # Hardware cursor planes are unreliable on QEMU's virtio-gpu.
              # Appends, because installMugenSystemDefaults only copies once.
              home.activation.vmHyprCursorTweak =
                lib.hm.dag.entryAfter [ "installMugenSystemDefaults" ] ''
                  conf="$HOME/.config/hypr/hyprland.conf"
                  if [[ -f "$conf" ]] && ! grep -q no_hardware_cursors "$conf"; then
                    printf '\n# QEMU/virtio: hardware cursor planes are unreliable\ncursor {\n  no_hardware_cursors = true\n}\n' >> "$conf"
                  fi
                '';
            };
          }
        ];
      };
    };
}
