# runtime/

The plugin's native payload (scripts, Lua, binaries-to-copies). `install.sh`
checksums every file in here: changing any of them re-triggers the install
steps on the next enable, an unchanged checksum skips. Add real files and
reference them from `install.sh` as `"$RUNTIME"/<file>`.
