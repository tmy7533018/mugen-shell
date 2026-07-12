# Bootable demo / smoke-test VM — not a real host config.
#
#   nix build .#nixosConfigurations.vm.config.system.build.vm
#   ./result/bin/run-mugen-vm-vm
#
# Boots straight into Hyprland with mugen-shell running (user `mugen`,
# password `mugen`). Exists so the whole Nix packaging chain — NixOS
# module, home-manager module, config-copy activation, exec-once
# autostart — can be exercised end-to-end without touching a real host.
{ pkgs, ... }:

{
  programs.mugen-shell.enable = true;

  networking.hostName = "mugen-vm";

  users.users.mugen = {
    isNormalUser = true;
    initialPassword = "mugen";
    extraGroups = [ "wheel" "networkmanager" "video" "audio" ];
  };
  security.sudo.wheelNeedsPassword = false;

  services.greetd = {
    enable = true;
    settings = {
      # Autologin once at boot; fall back to a real prompt after logout.
      initial_session = {
        command = "Hyprland";
        user = "mugen";
      };
      default_session = {
        command = "${pkgs.greetd}/bin/agreety --cmd Hyprland";
        user = "greeter";
      };
    };
  };

  # The exec-once lines in hyprland.conf need the configs that
  # home-manager's first activation copies into ~/.config — don't let
  # greetd race it on first boot.
  systemd.services.greetd = {
    after = [ "home-manager-mugen.service" ];
    wants = [ "home-manager-mugen.service" ];
  };

  # Poke at the guest with: ssh -p 2222 mugen@localhost (password: mugen)
  services.openssh.enable = true;
  services.openssh.settings.PasswordAuthentication = true;

  virtualisation.vmVariant.virtualisation = {
    memorySize = 8192;
    cores = 4;
    forwardPorts = [
      # Loopback only — the guest has a well-known password, so don't
      # expose its sshd to the LAN (the default binds 0.0.0.0).
      {
        from = "host";
        host.address = "127.0.0.1";
        host.port = 2222;
        guest.port = 22;
      }
    ];
    # No virgl/host GL: a nix-built qemu can't load the host's mesa
    # drivers on non-NixOS hosts, so the guest renders via llvmpipe.
    # On a NixOS host, switch to virtio-vga-gl + gl=on for smooth output.
    qemu.options = [
      "-vga none"
      "-device virtio-vga"
      "-display gtk,gl=off,show-cursor=on"
    ];
  };

  system.stateVersion = "25.05";
}
