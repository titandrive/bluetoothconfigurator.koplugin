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
    cd "$repo_dir"
    zip -q "$output_path" \
        bluetoothconfigurator.koplugin/_meta.lua \
        bluetoothconfigurator.koplugin/bluetooth_updater.lua \
        bluetoothconfigurator.koplugin/input_android_patched.lua \
        bluetoothconfigurator.koplugin/main.lua
)

# KOReader's unpackArchive(..., true) strips exactly one leading directory.
# Older plugin updaters depend on that behavior, so every file must have this
# one wrapper and no second nested directory.
if unzip -Z1 "$output_path" | grep -Ev '^bluetoothconfigurator\.koplugin/[^/]+$' | grep -q .; then
    echo "Invalid release archive: expected exactly one plugin wrapper directory" >&2
    exit 1
fi

echo "$output_path"
