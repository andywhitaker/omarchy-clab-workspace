#!/usr/bin/env bash
# install.sh: Link and activate Omarchy Containerlab Workspace Plugin for local development

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OMARCHY_PLUGINS_DIR="$HOME/.config/omarchy/plugins"
PLUGIN_ID="awhitaker.clab-workspace"
OLD_PLUGIN_ID="awhitaker.containerlab"

echo "=== Installing Containerlab Workspace Plugin (Dev Link) ==="

# 1. Clean up old plugin ID if present
omarchy plugin disable "$OLD_PLUGIN_ID" >/dev/null 2>&1 || true
rm -rf "$OMARCHY_PLUGINS_DIR/$OLD_PLUGIN_ID"

# 2. Setup plugin symlink in ~/.config/omarchy/plugins
mkdir -p "$OMARCHY_PLUGINS_DIR"
TARGET_PLUGIN_DIR="$OMARCHY_PLUGINS_DIR/$PLUGIN_ID"

if [ -L "$TARGET_PLUGIN_DIR" ] && [ "$(readlink -f "$TARGET_PLUGIN_DIR")" = "$(readlink -f "$SCRIPT_DIR")" ]; then
    echo "✓ Plugin is already symlinked: $TARGET_PLUGIN_DIR"
elif [ "$SCRIPT_DIR" = "$TARGET_PLUGIN_DIR" ]; then
    echo "✓ Running directly from plugin directory: $TARGET_PLUGIN_DIR"
else
    rm -rf "$TARGET_PLUGIN_DIR"
    ln -s "$SCRIPT_DIR" "$TARGET_PLUGIN_DIR"
    echo "✓ Symlinked $SCRIPT_DIR -> $TARGET_PLUGIN_DIR"
fi

# 3. Validate plugin manifest
omarchy plugin validate "$SCRIPT_DIR"
echo "✓ Validated plugin manifest against Omarchy schema"

# 4. Rescan shell plugins and enable
omarchy-shell shell rescanPlugins >/dev/null 2>&1 || true
omarchy plugin enable "$PLUGIN_ID" --section right >/dev/null 2>&1 || true
echo "✓ Enabled Omarchy shell plugin ($PLUGIN_ID)"

echo ""
echo "=== Containerlab Workspace Plugin is Ready! ==="
echo "All Hyprland window rules and keybindings are dynamically managed by ContainerlabService.qml."
echo "No manual changes to ~/.config/hypr/ are needed."
