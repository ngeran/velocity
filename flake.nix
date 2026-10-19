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

      checks = forAllSystems (pkgs: {
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
