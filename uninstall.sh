#!/usr/bin/env bash
# uninstall.sh: Uninstall Omarchy Containerlab Workspace Plugin

set -euo pipefail

HYPR_DIR="$HOME/.config/hypr"
OMARCHY_PLUGINS_DIR="$HOME/.config/omarchy/plugins"
PLUGIN_ID="awhitaker.containerlab"

echo "=== Uninstalling Omarchy Containerlab Workspace Plugin ==="

# 1. Disable plugin in shell
omarchy plugin disable "$PLUGIN_ID" >/dev/null 2>&1 || true
echo "✓ Disabled plugin $PLUGIN_ID"

# 2. Remove plugin files / symlink
rm -rf "$OMARCHY_PLUGINS_DIR/$PLUGIN_ID"
echo "✓ Removed $OMARCHY_PLUGINS_DIR/$PLUGIN_ID"

# 3. Remove window rules from hyprland.lua
HYPRLAND_LUA="$HYPR_DIR/hyprland.lua"
if [ -f "$HYPRLAND_LUA" ]; then
    sed -i '/-- BEGIN OMARCHY_CONTAINERLAB/,/-- END OMARCHY_CONTAINERLAB/d' "$HYPRLAND_LUA"
    echo "✓ Cleaned window rules from $HYPRLAND_LUA"
fi

# 4. Remove keybindings from bindings.lua
BINDINGS_LUA="$HYPR_DIR/bindings.lua"
if [ -f "$BINDINGS_LUA" ]; then
    sed -i '/-- BEGIN OMARCHY_CONTAINERLAB/,/-- END OMARCHY_CONTAINERLAB/d' "$BINDINGS_LUA"
    echo "✓ Cleaned keybindings from $BINDINGS_LUA"
fi

# 5. Reload Hyprland and rescan plugins
hyprctl reload >/dev/null 2>&1 || true
omarchy-shell shell rescanPlugins >/dev/null 2>&1 || true
echo "✓ Reloaded Hyprland and Omarchy shell"

echo "=== Containerlab Plugin uninstalled successfully ==="
