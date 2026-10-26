# home-manager module: programs.velocity
#
#   imports = [ velocity.homeManagerModules.default ];
#   programs.velocity = {
#     enable = true;
#     checkout = "/home/me/src/velocity";        # linked to ~/.config/quickshell
#     plugins = [ (velocity.lib.mkPlugin pkgs { src = ./plugins/acme.weather; }) ];
#   };
#
# Plugins from `plugins` are read-only system plugins (VELOCITY_PLUGIN_PATH).
# Like every plugin they start disabled: `velocity-plugin enable <id>`.
self:
{ config, lib, pkgs, ... }:

let
  cfg = config.programs.velocity;
  cli = self.packages.${pkgs.stdenv.hostPlatform.system}.velocity-plugin;
  pluginTree = pkgs.symlinkJoin { name = "velocity-plugins"; paths = cfg.plugins; };
  pluginPath = "${pluginTree}/share/velocity/plugins";

  # The bar forks hyprctl/journalctl/bluetoothctl/wpctl from the system
  # profile; runtimeInputs adds what velocity itself needs on top.
  # /run/wrappers/bin carries the setuid wrappers (mount, fusermount3, …).
  servicePath = lib.concatStringsSep ":" [
    (lib.makeBinPath cfg.runtimeInputs)
    "/etc/profiles/per-user/%u/bin"
    "/run/wrappers/bin"
    "/run/current-system/sw/bin"
  ];

  unit = name: {
    Unit = {
      Description = "Velocity ${name} (Quickshell)";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "${cfg.quickshellPackage}/bin/quickshell -c ${name}";
      Restart = "on-failure";
      RestartSec = 3;
      Environment = [
        "PATH=${servicePath}"
        "VELOCITY_PLUGIN_PATH=${pluginPath}"
      ];
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };
in
{
  options.programs.velocity = {
    enable = lib.mkEnableOption "the velocity Quickshell bar";

    checkout = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "/home/me/src/velocity";
      description = ''
        Absolute path of the velocity checkout. Linked out of store (so it
        stays writable) to ~/.config/quickshell. null = manage the link
        yourself (tools/deploy-link).
      '';
    };

    plugins = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = [ ];
      description = "Plugin packages built with velocity.lib.mkPlugin.";
    };

    quickshellPackage = lib.mkOption {
      type = lib.types.package;
      default = pkgs.quickshell;
      defaultText = lib.literalExpression "pkgs.quickshell";
      description = "Quickshell build that runs the bar and settings.";
    };

    runtimeInputs = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      # Tools velocity's services shell out to directly — they must not depend
      # on happening to be installed system-wide:
      #   curl (weather) · util-linux (lsblk, storage) · procps (pkill) ·
      #   bash (thumbnail worker) · awww/ffmpeg (wallpaper backends, poster
      #   frames) · matugen (wallpaper → palette) · mpvpaper (engine backend)
      default = with pkgs; [ netcat networkmanager upower qrencode nodejs git coreutils findutils gnused gnugrep curl util-linux procps bash awww ffmpeg matugen mpvpaper ];
      defaultText = lib.literalExpression "with pkgs; [ netcat networkmanager upower qrencode nodejs git coreutils findutils gnused gnugrep curl util-linux procps bash awww ffmpeg matugen mpvpaper ]";
      description = "Tools on the bar/settings services' PATH (ahead of the user and system profiles).";
    };

    systemd.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Run the bar and settings as systemd user services (quickshell-bar, quickshell-settings).";
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [ cli ];
    home.sessionVariables.VELOCITY_PLUGIN_PATH = pluginPath;

    home.file.".config/quickshell" = lib.mkIf (cfg.checkout != null) {
      source = config.lib.file.mkOutOfStoreSymlink cfg.checkout;
    };

    systemd.user.services = lib.mkIf cfg.systemd.enable {
      quickshell-bar = unit "bar";
      quickshell-settings = unit "settings";
    };
  };
}
