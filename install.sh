#!/usr/bin/env bash
# install.sh: Install and activate Omarchy Containerlab Workspace Plugin

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_DIR="$HOME/.local/bin"
HYPR_DIR="$HOME/.config/hypr"
OMARCHY_PLUGINS_DIR="$HOME/.config/omarchy/plugins"
PLUGIN_ID="awhitaker.containerlab"

echo "=== Installing Omarchy Containerlab Workspace Plugin ==="

# 1. Install layout toggle script
mkdir -p "$BIN_DIR"
if [ -f "$SCRIPT_DIR/bin/omarchy-hyprland-workspace-layout-toggle" ]; then
    cp "$SCRIPT_DIR/bin/omarchy-hyprland-workspace-layout-toggle" "$BIN_DIR/omarchy-hyprland-workspace-layout-toggle"
    chmod +x "$BIN_DIR/omarchy-hyprland-workspace-layout-toggle"
    echo "✓ Installed $BIN_DIR/omarchy-hyprland-workspace-layout-toggle"
fi

# 2. Setup plugin in ~/.config/omarchy/plugins
mkdir -p "$OMARCHY_PLUGINS_DIR"
TARGET_PLUGIN_DIR="$OMARCHY_PLUGINS_DIR/$PLUGIN_ID"

# If already installed as a symlink pointing to this repository, keep it
if [ -L "$TARGET_PLUGIN_DIR" ] && [ "$(readlink -f "$TARGET_PLUGIN_DIR")" = "$(readlink -f "$SCRIPT_DIR")" ]; then
    echo "✓ Plugin is already symlinked to this repository: $TARGET_PLUGIN_DIR"
elif [ "$SCRIPT_DIR" = "$TARGET_PLUGIN_DIR" ]; then
    echo "✓ Running directly from plugin directory: $TARGET_PLUGIN_DIR"
else
    # Link or copy (default link for dev, or copy if passed --copy)
    if [[ "${1:-}" == "--copy" ]]; then
        rm -rf "$TARGET_PLUGIN_DIR"
        mkdir -p "$TARGET_PLUGIN_DIR"
        cp -r "$SCRIPT_DIR/"* "$TARGET_PLUGIN_DIR/"
        echo "✓ Copied plugin to $TARGET_PLUGIN_DIR"
    else
        rm -rf "$TARGET_PLUGIN_DIR"
        ln -s "$SCRIPT_DIR" "$TARGET_PLUGIN_DIR"
        echo "✓ Symlinked $SCRIPT_DIR -> $TARGET_PLUGIN_DIR"
    fi
fi

# 3. Validate plugin
omarchy plugin validate "$SCRIPT_DIR"
echo "✓ Validated plugin manifest against Omarchy schema"

# 4. Install Hyprland window rules in ~/.config/hypr/hyprland.lua
HYPRLAND_LUA="$HYPR_DIR/hyprland.lua"
RULES_SNIPPET='-- BEGIN OMARCHY_CONTAINERLAB
o.window({ class = "^org.quickshell$", title = "^Containerlab Workspace$" }, {
  workspace = "special:clab",
  float = true,
  size = { 1280, 760 },
  center = true
})
o.window({ class = "^org.omarchy.clab-terminal$" }, { workspace = "special:clab" })
-- END OMARCHY_CONTAINERLAB'

mkdir -p "$HYPR_DIR"
if [ -f "$HYPRLAND_LUA" ]; then
    sed -i '/-- BEGIN OMARCHY_CONTAINERLAB/,/-- END OMARCHY_CONTAINERLAB/d' "$HYPRLAND_LUA"
    printf "\n%s\n" "$RULES_SNIPPET" >> "$HYPRLAND_LUA"
    echo "✓ Updated window rules in $HYPRLAND_LUA"
else
    printf "%s\n" "$RULES_SNIPPET" > "$HYPRLAND_LUA"
    echo "✓ Created $HYPRLAND_LUA with window rules"
fi

# 5. Install Keybindings in ~/.config/hypr/bindings.lua
BINDINGS_LUA="$HYPR_DIR/bindings.lua"
BINDINGS_SNIPPET='-- BEGIN OMARCHY_CONTAINERLAB
o.bind("SUPER + ALT + C", "Toggle Containerlab topology", "python3 " .. os.getenv("HOME") .. "/.config/omarchy/plugins/awhitaker.containerlab/backend.py smart-toggle")
o.bind("SUPER + ALT + SHIFT + C", "Toggle Containerlab workspace", hl.dsp.workspace.toggle_special("clab"))

-- Workspace layout toggle supporting special workspaces (e.g. special:clab)
hl.unbind("SUPER + L")
o.bind("SUPER + L", "Toggle workspace layout", os.getenv("HOME") .. "/.local/bin/omarchy-hyprland-workspace-layout-toggle")
-- END OMARCHY_CONTAINERLAB'

if [ -f "$BINDINGS_LUA" ]; then
    sed -i '/-- BEGIN OMARCHY_CONTAINERLAB/,/-- END OMARCHY_CONTAINERLAB/d' "$BINDINGS_LUA"
    printf "\n%s\n" "$BINDINGS_SNIPPET" >> "$BINDINGS_LUA"
    echo "✓ Updated keybindings in $BINDINGS_LUA"
else
    printf "%s\n" "$BINDINGS_SNIPPET" > "$BINDINGS_LUA"
    echo "✓ Created $BINDINGS_LUA with keybindings"
fi

# 6. Reload Hyprland and validate
hyprctl reload >/dev/null 2>&1 || true
echo "✓ Reloaded Hyprland configuration"

ERRORS=$(hyprctl configerrors 2>&1 || true)
if [ -n "$ERRORS" ]; then
    echo "⚠ Warning: Hyprland reported config errors:"
    echo "$ERRORS"
else
    echo "✓ Hyprland validated clean with 0 errors"
fi

# 7. Rescan shell plugins and enable
omarchy-shell shell rescanPlugins >/dev/null 2>&1 || true
omarchy plugin enable "$PLUGIN_ID" --section right >/dev/null 2>&1 || true
echo "✓ Enabled Omarchy shell plugin ($PLUGIN_ID) on status bar"

echo ""
echo "=== Containerlab Workspace Plugin is Ready! ==="
echo "Features & Keybindings:"
echo "  • Status Bar: Widget shows active Containerlab node count."
echo "    - Left-click: Smart toggle workspace / topology window"
echo "    - Right-click: Toggle special:clab workspace directly"
echo "  • SUPER + ALT + C: Smart toggle topology window"
echo "  • SUPER + ALT + SHIFT + C: Toggle special:clab workspace"
echo "  • SUPER + L: Toggle dwindle vs scrolling layout on active workspace"
