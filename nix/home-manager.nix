{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.programs.mugen-shell;
in
{
  options.programs.mugen-shell = {
    enable = lib.mkEnableOption "the mugen-shell desktop (Quickshell + Hyprland)";

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.mugen-shell or null;
      defaultText = lib.literalExpression "pkgs.mugen-shell";
      description = "The mugen-shell QML package (UI tree, scripts, assets).";
    };

    ai = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Whether to install and run the mugen-ai backend service.";
      };

      package = lib.mkOption {
        type = lib.types.package;
        default = pkgs.mugen-ai or null;
        defaultText = lib.literalExpression "pkgs.mugen-ai";
        description = "The mugen-ai package (Go backend binary).";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    # Readonly symlink so `quickshell -c mugen-shell` finds the QML tree.
    # The result is a single symlink into /nix/store, regenerated on every
    # home-manager activation so flake updates propagate automatically.
    xdg.configFile."quickshell/mugen-shell".source = cfg.package;

    # mugen-ai binary into the user's profile so PATH and the systemd unit
    # below can find it.
    home.packages = lib.optionals cfg.ai.enable [ cfg.ai.package ];

    systemd.user.services.mugen-ai = lib.mkIf cfg.ai.enable {
      Unit = {
        Description = "mugen-ai backend HTTP server";
        After = [ "graphical-session.target" ];
      };
      Service = {
        ExecStart = "${cfg.ai.package}/bin/mugen-ai serve";
        Restart = "on-failure";
        RestartSec = 2;
      };
      Install = {
        WantedBy = [ "default.target" ];
      };
    };
  };
}
