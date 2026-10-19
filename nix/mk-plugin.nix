# A plugin folder → a package exposing share/velocity/plugins/<id> (a store
# symlink). The engine treats it as a read-only "system" plugin: symlinks are
# allowed there, and it can be enabled/disabled/placed but not removed.
#
#   velocity.lib.mkPlugin pkgs { src = ./my-plugin; }
#   velocity.lib.mkPlugin pkgs { src = fetchFromGitHub { … }; }
{ lib, runCommand, src, id ? null }:

let
  manifest = builtins.fromJSON (builtins.readFile "${src}/manifest.json");
  pluginId = if id != null then id else manifest.id;
in
runCommand "velocity-plugin-${pluginId}" { } ''
  mkdir -p $out/share/velocity/plugins
  ln -s ${src} $out/share/velocity/plugins/${lib.escapeShellArg pluginId}
''
