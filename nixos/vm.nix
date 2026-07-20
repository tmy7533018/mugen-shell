# Bootable demo / smoke-test VM — not a real host config.
#
#   nix build .#nixosConfigurations.vm.config.system.build.vm
#   ./result/bin/run-mugen-vm-vm
#
# Boots into Hyprland with mugen-shell running (user/password `mugen`).
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
      # start-hyprland (0.51+) is the upstream launcher: it sets up the session
      # env and the crash-restart watchdog that bare `Hyprland` skips.
      initial_session = {
        command = "start-hyprland";
        user = "mugen";
      };
      default_session = {
        command = "${pkgs.greetd}/bin/agreety --cmd start-hyprland";
        user = "greeter";
      };
    };
  };

  # hyprland.conf's exec-once lines need the configs home-manager's first
  # activation copies into ~/.config, so greetd must not race it on first boot.
  systemd.services.greetd = {
    after = [ "home-manager-mugen.service" ];
    wants = [ "home-manager-mugen.service" ];
  };

  services.openssh.enable = true;
  services.openssh.settings.PasswordAuthentication = true;

  virtualisation.vmVariant.virtualisation = {
    memorySize = 8192;
    cores = 4;
    forwardPorts = [
      # Loopback only: the guest has a well-known password and the default
      # would bind 0.0.0.0, exposing its sshd to the LAN.
      {
        from = "host";
        host.address = "127.0.0.1";
        host.port = 2222;
        guest.port = 22;
      }
    ];
    # No virgl: a nix-built qemu can't load a non-NixOS host's mesa drivers,
    # so the guest renders via llvmpipe. On a NixOS host, virtio-vga-gl +
    # gl=on is much smoother.
    qemu.options = [
      "-vga none"
      "-device virtio-vga"
      "-display gtk,gl=off,show-cursor=on"
    ];
  };

  system.stateVersion = "25.05";
}
