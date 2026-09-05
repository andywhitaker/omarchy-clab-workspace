import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

BarWidget {
    id: root
    moduleName: "awhitaker.clab-workspace"

    implicitWidth: widgetBtn.implicitWidth
    implicitHeight: widgetBtn.implicitHeight

    readonly property string pluginDir: {
        var base = Qt.resolvedUrl(".").toString();
        base = base.replace(/^file:\/\//, "");
        if (base.endsWith("/")) {
            base = base.substring(0, base.length - 1);
        }
        return base || (Quickshell.env("HOME") + "/.config/omarchy/plugins/awhitaker.clab-workspace");
    }
    property string backendScript: pluginDir + "/backend.py"

    property int topologyCount: 0
    property int nodeCount: 0
    property string activeLabName: ""

    function refresh() {
        if (!fetchProc.running) {
            fetchProc.running = true;
        }
    }

    Component.onCompleted: refresh()

    Timer {
        interval: 6000
        repeat: true
        running: true
        onTriggered: root.refresh()
    }

    Process {
        id: fetchProc
        command: ["python3", root.backendScript, "get-topologies"]
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                try {
                    var data = JSON.parse(text);
                    var topos = data.topologies || [];
                    root.topologyCount = topos.length;
                    var total = 0;
                    for (var i = 0; i < topos.length; i++) {
                        total += (topos[i].nodes ? topos[i].nodes.length : 0);
                    }
                    root.nodeCount = total;
                    root.activeLabName = data.active_topology || (topos.length > 0 ? topos[0].name : "");
                } catch (e) {
                    // silently handle parse errors
                }
            }
        }
    }

    WidgetButton {
        id: widgetBtn
        anchors.fill: parent
        bar: root.bar
        text: root.nodeCount > 0 ? ("\uf0e8 " + root.nodeCount) : "\uf0e8"
        active: root.nodeCount > 0
        useActiveColor: true
        activeColor: Color.accent
        tooltipText: root.topologyCount > 0
            ? ("Containerlab: " + root.activeLabName + " (" + root.nodeCount + " nodes running)\nClick or SUPER+ALT+C: Toggle topology\nRight-click: Toggle workspace")
            : "Containerlab: No active topologies\nClick: Toggle topology"
        onPressed: function(buttonCode) {
            if (buttonCode === Qt.RightButton) {
                Quickshell.execDetached(["hyprctl", "dispatch", "hl.dsp.workspace.toggle_special(\"clab\")"]);
            } else {
                Quickshell.execDetached(["python3", root.backendScript, "smart-toggle"]);
            }
        }
    }
}
