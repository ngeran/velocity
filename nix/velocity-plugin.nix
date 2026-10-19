# The velocity-plugin CLI. It runs the CHECKOUT's bin/velocity-plugin (not
# a store copy): the CLI shares bar/engine/lib with the running bar, and
# reads/writes next to it, so the two can never be different versions.
{ writeShellApplication, nodejs, git }:

writeShellApplication {
  name = "velocity-plugin";
  runtimeInputs = [ nodejs git ];
  text = ''
    root="''${VELOCITY_ROOT:-$HOME/.config/quickshell}"
    if [ ! -f "$root/bin/velocity-plugin" ]; then
      echo "velocity-plugin: no velocity checkout at $root (set VELOCITY_ROOT or programs.velocity.checkout)" >&2
      exit 1
    fi
    export VELOCITY_ROOT="$root"
    exec node "$root/bin/velocity-plugin" "$@"
  '';
}
