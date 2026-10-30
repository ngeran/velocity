{
  # Velocity — Quickshell bar + plugin engine for Hyprland.
  #
  # The checkout itself is the live config dir (~/.config/quickshell): the
  # bar writes plugins-state.json, bar-config.json, … into it, so velocity is
  # linked, not copied into the store. What the flake provides:
  #
  #   packages.<system>.velocity-plugin   CLI wrapper (runs the checkout's
  #                                       bin/velocity-plugin with node + git)
  #   lib.mkPlugin pkgs { src; }          a plugin folder → a read-only
  #                                       "system" plugin package
  #   homeManagerModules.default          programs.velocity (link, plugins,
  #                                       systemd user units)
  #   checks.<system>.gates               node test suites + plugin/engine gates
  description = "Velocity — Quickshell bar and plugin engine for Hyprland";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs }:
    let
      systems = [ "x86_64-linux" "aarch64-linux" ];
      forAllSystems = f: nixpkgs.lib.genAttrs systems (system: f nixpkgs.legacyPackages.${system});
    in
    {
      packages = forAllSystems (pkgs: rec {
        velocity-plugin = pkgs.callPackage ./nix/velocity-plugin.nix { };
        default = velocity-plugin;
      });

      lib.mkPlugin = pkgs: args: pkgs.callPackage ./nix/mk-plugin.nix args;

      homeManagerModules.default = import ./nix/hm-module.nix self;

      # Host-side half of velocity-lock: the PAM service it authenticates
      # against. Import on hosts that run the lock; without it velocity-lock
      # refuses to lock (it would wedge the session — see bin/velocity-lock).
      nixosModules.default = {
        security.pam.services.velocity-lock = { };
      };

      # Stub-eval of the HM module with its defaults (P3.11): catches option
      # type errors, broken defaults and undefined variables without needing
      # the home-manager flake as an input. The check's manifest depends on
      # the evaluated config, so a failed eval fails `nix flake check`.
      checks = forAllSystems (pkgs: {
        hm-module =
          let
            lib = pkgs.lib;
            evaluated = (lib.evalModules {
              modules = [
                { _module.args.pkgs = pkgs; }
                {
                  # Minimal home-manager surface the module touches.
                  options = {
                    home = lib.mkOption { type = lib.types.submodule {
                      options = {
                        packages = lib.mkOption { type = lib.types.listOf lib.types.raw; default = [ ]; };
                        sessionVariables = lib.mkOption { type = lib.types.attrsOf lib.types.raw; default = { }; };
                        file = lib.mkOption { type = lib.types.attrsOf lib.types.raw; default = { }; };
                      };
                    }; };
                    systemd = lib.mkOption { type = lib.types.submodule {
                      options.user = lib.mkOption { type = lib.types.submodule {
                        options.services = lib.mkOption { type = lib.types.attrsOf lib.types.raw; default = { }; };
                      }; }; };
                    };
                    lib = lib.mkOption { type = lib.types.submodule {
                      options.file = lib.mkOption { type = lib.types.attrsOf lib.types.raw; default = { }; };
                    }; };
                    xdg = lib.mkOption { type = lib.types.submodule {
                      options.configFile = lib.mkOption { type = lib.types.attrsOf lib.types.raw; default = { }; };
                    }; };
                    fonts = lib.mkOption { type = lib.types.submodule {
                      options.fontconfig = lib.mkOption { type = lib.types.submodule {
                        options.enable = lib.mkOption { type = lib.types.bool; default = false; };
                      }; }; };
                    };
                  };
                  config.lib.file.mkOutOfStoreSymlink = p: { outPath = p; };
                }
                (import ./nix/hm-module.nix self)
                { programs.velocity.enable = true; }
              ];
            }).config;
          in
          pkgs.runCommand "velocity-hm-module-eval"
            {
              manifest = builtins.toJSON {
                unitNames = builtins.attrNames evaluated.systemd.user.services;
                generatedFiles = builtins.attrNames evaluated.xdg.configFile;
                nPackages = builtins.length evaluated.home.packages;
                bindCount = builtins.length (builtins.fromJSON evaluated.xdg.configFile."velocity/keybinds.json".text).binds;
              };
            }
            "touch $out";

        gates = pkgs.runCommand "velocity-gates"
          { nativeBuildInputs = [ pkgs.nodejs pkgs.git ]; }
          ''
            cp -r ${self} src
            chmod -R u+w src
            cd src
            patchShebangs bin tools
            export HOME="$TMPDIR"
            for t in $(find bar settings plugins bin -name '*.test.mjs' | sort); do
              echo "== $t"
              node "$t"
            done
            node tools/check-plugins
            node tools/check-engine
            for d in plugins/*/ bar/builtins/*/; do
              [ -f "$d/manifest.json" ] || continue
              node bin/velocity-plugin validate "$d"
            done
            touch $out
          '';
      });
    };
}
