{
  description = "mugen-shell NixOS umbrella — system-level integration on top of the user-level flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # The user-level flake (homeManagerModules + packages + overlays).
    # `path:..` resolves to the repo root when this flake is fetched via
    # `?dir=nixos`; using a relative path keeps the two layers in lock-step.
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
      # The NixOS module body lives in the parent repo so the layout is one
      # source of truth; we just wrap it in an overlay-applying shim here.
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

      # Re-export user-level surface so a NixOS user only needs one flake
      # input — they can still pull homeManagerModules / packages from here.
      inherit (mugen-shell)
        packages
        homeManagerModules
        overlays
        ;

      # Smoke-test NixOS config used in CI / manual `nix build` checks.
      # It enables programs.mugen-shell.enable and forces every option
      # the module wires (Hyprland, hyprlock, pipewire, ...), so any
      # type/eval/dependency error in module.nix surfaces here without
      # waiting for someone to install on a real machine. Don't run this
      # as an actual host — it's a build-only scaffold.
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

      # Bootable demo VM — see vm.nix for what it does and how to run it.
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

              # Hardware cursor planes are unreliable on QEMU's virtio-gpu;
              # the copied hyprland.conf is mutable user config, so append
              # rather than fight the install-once activation above.
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
