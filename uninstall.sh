#!/usr/bin/env bash
# uninstall.sh: Uninstall Omarchy Containerlab Workspace Plugin

set -euo pipefail

OMARCHY_PLUGINS_DIR="$HOME/.config/omarchy/plugins"
PLUGIN_ID="awhitaker.clab-workspace"
OLD_PLUGIN_ID="awhitaker.containerlab"

echo "=== Uninstalling Omarchy Containerlab Workspace Plugin ==="

# 1. Disable plugin in shell
omarchy plugin disable "$PLUGIN_ID" >/dev/null 2>&1 || true
omarchy plugin disable "$OLD_PLUGIN_ID" >/dev/null 2>&1 || true
echo "✓ Disabled plugins in Omarchy shell"

# 2. Remove plugin files / symlinks
rm -rf "$OMARCHY_PLUGINS_DIR/$PLUGIN_ID" "$OMARCHY_PLUGINS_DIR/$OLD_PLUGIN_ID"
echo "✓ Removed plugin directories from $OMARCHY_PLUGINS_DIR"

# 3. Clean up legacy layout toggle script if present
BIN_DIR="$HOME/.local/bin"
if [ -f "$BIN_DIR/omarchy-hyprland-workspace-layout-toggle" ]; then
    rm -f "$BIN_DIR/omarchy-hyprland-workspace-layout-toggle"
    echo "✓ Removed legacy $BIN_DIR/omarchy-hyprland-workspace-layout-toggle"
fi

# 4. Clean up any legacy entries in hypr configs if present
HYPR_DIR="$HOME/.config/hypr"
if [ -f "$HYPR_DIR/hyprland.lua" ]; then
    sed -i '/-- BEGIN OMARCHY_CONTAINERLAB/,/-- END OMARCHY_CONTAINERLAB/d' "$HYPR_DIR/hyprland.lua"
fi
if [ -f "$HYPR_DIR/bindings.lua" ]; then
    sed -i '/-- BEGIN OMARCHY_CONTAINERLAB/,/-- END OMARCHY_CONTAINERLAB/d' "$HYPR_DIR/bindings.lua"
fi

# 5. Reload Hyprland and rescan plugins
hyprctl reload >/dev/null 2>&1 || true
omarchy-shell shell rescanPlugins >/dev/null 2>&1 || true
echo "✓ Reloaded Hyprland and Omarchy shell"
echo "=== Containerlab Workspace Plugin uninstalled successfully ==="
