#!/bin/sh
set -eu

repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
plugin_dir="$repo_dir/bluetoothconfigurator.koplugin"
version=$(sed -n 's/.*version = "\([^"]*\)".*/\1/p' "$plugin_dir/_meta.lua")
output_path="${1:-$repo_dir/bluetoothconfigurator.koplugin-v$version.zip}"

if [ -z "$version" ]; then
    echo "Could not read plugin version from _meta.lua" >&2
    exit 1
fi

rm -f -- "$output_path"
(
    cd "$plugin_dir"
    zip -q "$output_path" _meta.lua bluetooth_updater.lua input_android_patched.lua main.lua
)

# v2.2.3 and older updaters extract directly into the installed plugin
# directory. Keep files at the ZIP root so those versions can self-repair.
if unzip -Z1 "$output_path" | grep -q '/'; then
    echo "Invalid release archive: plugin files must be at the ZIP root" >&2
    exit 1
fi

echo "$output_path"
