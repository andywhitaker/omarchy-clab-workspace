import QtQuick
import Quickshell
import Quickshell.Hyprland

Item {
    id: root

    // Injected by Omarchy shell
    property var shell: null
    property var manifest: null

    // Resolved plugin path on disk
    readonly property string pluginDir: {
        var base = Qt.resolvedUrl(".").toString();
        base = base.replace(/^file:\/\//, "");
        if (base.endsWith("/")) {
            base = base.substring(0, base.length - 1);
        }
        return base;
    }

    readonly property string backendScript: pluginDir + "/backend.py"
    readonly property string layoutToggleScript: pluginDir + "/bin/omarchy-hyprland-workspace-layout-toggle"

    function buildApplyScript() {
        var cmds = [
            // Hyprland Window Rules for Containerlab Workspace
            'o.window({ class = "^org.quickshell$", title = "^Containerlab Workspace$" }, { workspace = "special:clab", float = true, size = { 1280, 760 }, center = true })',
            'o.window({ class = "^org.omarchy.clab-terminal$" }, { workspace = "special:clab" })',

            // Keybindings
            'o.bind("SUPER + ALT + C", "Toggle Containerlab topology", "python3 ' + backendScript + ' smart-toggle")',
            'o.bind("SUPER + ALT + SHIFT + C", "Toggle Containerlab workspace", hl.dsp.workspace.toggle_special("clab"))',
            'hl.unbind("SUPER + L")',
            'o.bind("SUPER + L", "Toggle workspace layout", "' + layoutToggleScript + '")'
        ];
        return cmds.join("; ");
    }

    function buildCleanupScript() {
        var cmds = [
            'hl.unbind("SUPER + ALT + C")',
            'hl.unbind("SUPER + ALT + SHIFT + C")',
            'hl.unbind("SUPER + L")',
            'o.bind("SUPER + L", "Toggle workspace layout", "omarchy-hyprland-workspace-layout-toggle")'
        ];
        return cmds.join("; ");
    }

    function applyRulesAndBindings() {
        var script = buildApplyScript();
        Quickshell.execDetached(["hyprctl", "eval", script]);
    }

    function cleanupRulesAndBindings() {
        var script = buildCleanupScript();
        Quickshell.execDetached(["hyprctl", "eval", script]);
    }

    Component.onCompleted: {
        Qt.callLater(applyRulesAndBindings);
    }

    Component.onDestruction: {
        cleanupRulesAndBindings();
    }

    // Automatically re-apply after any Hyprland reload (theme switch, monitor hotplug, hyprctl reload, etc.)
    Connections {
        target: Hyprland

        function onRawEvent(event) {
            if (event?.name === "configreloaded") {
                Qt.callLater(applyRulesAndBindings);
            }
        }
    }
}
