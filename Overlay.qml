import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons
import qs.Ui

Item {
    id: root

    property string omarchyPath: Quickshell.env("OMARCHY_PATH")
    property string pluginDir: Quickshell.env("HOME") + "/.config/omarchy/plugins/awhitaker.containerlab"
    property string backendScript: pluginDir + "/backend.py"

    property var shell: null
    property bool closingFromHost: false

    property bool opened: true
    property string currentTab: "workspace" // "workspace" or "settings"
    property var topologies: []
    property int activeTopoIndex: 0
    readonly property var currentTopology: (topologies && topologies.length > activeTopoIndex && activeTopoIndex >= 0)
        ? topologies[activeTopoIndex]
        : null

    property bool shiftHeld: false
    property string toastMessage: ""

    // Lifecycle methods
    function open(payloadJson) {
        closingFromHost = false;
        root.opened = true;
        window.visible = true;
        try {
            var p = JSON.parse(payloadJson || "{}");
            if (p.tab) root.currentTab = p.tab;
        } catch (e) {}
        refreshTopologies();
        Qt.callLater(function() { if (keyCatcher) keyCatcher.forceActiveFocus(); });
    }

    function close() {
        closingFromHost = true;
        root.opened = false;
        window.visible = false;
        closingFromHost = false;
    }

    function requestClose() {
        if (root.shell && typeof root.shell.hide === "function") {
            root.shell.hide("awhitaker.containerlab");
        } else {
            root.close();
        }
    }

    function toggle() {
        if (window.visible) {
            requestClose();
        } else {
            open("{}");
        }
    }

    Component.onCompleted: {
        refreshTopologies();
    }

    Timer {
        id: autoRefreshTimer
        interval: 15000
        repeat: true
        running: root.opened && root.currentTab === "workspace"
        onTriggered: root.refreshTopologies()
    }

    function refreshTopologies() {
        if (!fetchProc.running) {
            fetchProc.running = true;
        }
    }

    function showToast(msg) {
        root.toastMessage = msg;
        toastTimer.restart();
    }

    function launchNode(node, grouped) {
        root.shiftHeld = false;
        if (!node) return;
        var target = (node.app === "browser") ? (node.url || node.default_url) : (node.command || node.default_command);
        if (!target) {
            showToast("No command or URL specified for " + node.name);
            return;
        }
        var cmd = ["python3", root.backendScript, "launch", "--app", node.app, "--target", target, "--name", node.name];
        if (grouped) {
            cmd.push("--grouped");
        }
        Quickshell.execDetached(cmd);
        var toastDesc = (node.app === "browser") ? "Browser" : (grouped ? "Terminal (Grouped)" : "Terminal");
        showToast("Launched " + node.name + " (" + toastDesc + ")");
    }

    function saveSettings(settingsMap) {
        var jsonStr = JSON.stringify(settingsMap);
        saveProc.command = ["python3", root.backendScript, "save-settings", jsonStr];
        saveProc.running = true;
    }

    Timer {
        id: toastTimer
        interval: 3500
        repeat: false
        onTriggered: root.toastMessage = ""
    }

    Process {
        id: fetchProc
        command: ["python3", root.backendScript, "get-topologies"]
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                try {
                    var data = JSON.parse(text);
                    root.topologies = data.topologies || [];
                    if (root.activeTopoIndex >= root.topologies.length) {
                        root.activeTopoIndex = 0;
                    }
                } catch (e) {
                    console.warn("Containerlab: JSON parse error:", e);
                }
            }
        }
    }

    Process {
        id: saveProc
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                root.showToast("\udb81\ud12c Settings saved successfully!");
                if (typeof settingsView !== "undefined" && settingsView) settingsView.forceReload();
                root.refreshTopologies();
            }
        }
    }

    FloatingWindow {
        id: window
        title: "Containerlab Workspace"
        visible: root.opened
        color: Color.menu.background
        implicitWidth: Style.space(1240)
        implicitHeight: Style.space(750)
        minimumSize: Qt.size(Style.space(800), Style.space(500))

        onVisibleChanged: {
            root.opened = visible;
            if (!visible && !root.closingFromHost && root.shell && typeof root.shell.hide === "function") {
                root.shell.hide("awhitaker.containerlab");
            }
        }

        Rectangle {
            anchors.fill: parent
            color: Color.menu.background

            FocusScope {
                id: keyCatcher
                anchors.fill: parent
                anchors.margins: Style.space(12)
                focus: true

                Keys.priority: Keys.BeforeItem
                Keys.onPressed: function(event) {
                    if (event.key === Qt.Key_Shift) {
                        root.shiftHeld = true;
                    }
                    if (event.key === Qt.Key_Escape) {
                        root.requestClose();
                        event.accepted = true;
                    }
                }
                Keys.onReleased: function(event) {
                    if (event.key === Qt.Key_Shift) {
                        root.shiftHeld = false;
                    }
                }

                Column {
                    anchors.fill: parent
                    spacing: Style.space(12)

                    // Top Header Bar
                    Rectangle {
                        id: headerBar
                        width: parent.width
                        height: Style.space(48)
                        radius: Style.cornerRadius
                        color: "#08ffffff"
                        border.width: 1
                        border.color: Util.alpha(Color.menu.border, 0.4)

                        Item {
                            anchors.fill: parent
                            anchors.leftMargin: Style.space(14)
                            anchors.rightMargin: Style.space(14)

                            // Left: Logo & Lab Switcher
                            Row {
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: Style.space(10)

                                Text {
                                    text: "\uf0e8"
                                    font.family: Style.font.family
                                    font.pixelSize: Style.font.display
                                    color: Color.accent
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                Text {
                                    text: "Containerlab"
                                    font.family: Style.font.family
                                    font.pixelSize: Style.font.heading
                                    font.bold: true
                                    color: Color.menu.text
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                // Lab Selector pills
                                Repeater {
                                    model: root.topologies

                                    Rectangle {
                                        required property var modelData
                                        required property int index
                                        readonly property bool isSelected: index === root.activeTopoIndex

                                        width: labTitle.implicitWidth + Style.space(18)
                                        height: Style.space(28)
                                        radius: Style.cornerRadius
                                        color: isSelected ? "#405e81ac" : "#0fffffff"
                                        border.width: 1
                                        border.color: isSelected ? Color.accent : "transparent"
                                        anchors.verticalCenter: parent.verticalCenter

                                        Text {
                                            id: labTitle
                                            anchors.centerIn: parent
                                            text: modelData.name + " (" + modelData.node_count + ")"
                                            font.family: Style.font.family
                                            font.pixelSize: Style.font.caption
                                            font.bold: isSelected
                                            color: isSelected ? Color.accent : Color.menu.text
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: root.activeTopoIndex = index
                                        }
                                    }
                                }
                            }

                            // Center: View Tabs Switcher
                            Row {
                                anchors.centerIn: parent
                                spacing: Style.space(6)

                                // Workspace Tab Button
                                Rectangle {
                                    width: Style.space(160)
                                    height: Style.space(32)
                                    radius: Style.cornerRadius
                                    color: root.currentTab === "workspace" ? Color.accent : "#0fffffff"

                                    Row {
                                        anchors.centerIn: parent
                                        spacing: Style.space(6)
                                        Text {
                                            text: "\udb81\udf7a"
                                            font.family: Style.font.family
                                            font.pixelSize: Style.font.body
                                            color: root.currentTab === "workspace" ? Color.menu.background : Color.menu.text
                                        }
                                        Text {
                                            text: "Workspace"
                                            font.family: Style.font.family
                                            font.pixelSize: Style.font.body
                                            font.bold: root.currentTab === "workspace"
                                            color: root.currentTab === "workspace" ? Color.menu.background : Color.menu.text
                                        }
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.currentTab = "workspace"
                                    }
                                }

                                // Settings Tab Button
                                Rectangle {
                                    width: Style.space(160)
                                    height: Style.space(32)
                                    radius: Style.cornerRadius
                                    color: root.currentTab === "settings" ? Color.accent : "#0fffffff"

                                    Row {
                                        anchors.centerIn: parent
                                        spacing: Style.space(6)
                                        Text {
                                            text: "\udb81\ude93"
                                            font.family: Style.font.family
                                            font.pixelSize: Style.font.body
                                            color: root.currentTab === "settings" ? Color.menu.background : Color.menu.text
                                        }
                                        Text {
                                            text: "Device Settings"
                                            font.family: Style.font.family
                                            font.pixelSize: Style.font.body
                                            font.bold: root.currentTab === "settings"
                                            color: root.currentTab === "settings" ? Color.menu.background : Color.menu.text
                                        }
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.currentTab = "settings"
                                    }
                                }
                            }

                            // Right: Refresh & Close
                            Row {
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: Style.space(6)

                                // Refresh
                                Rectangle {
                                    width: Style.space(32)
                                    height: Style.space(32)
                                    radius: Style.space(6)
                                    color: "#0fffffff"

                                    Text {
                                        anchors.centerIn: parent
                                        text: "\udb81\udc50"
                                        font.family: Style.font.family
                                        font.pixelSize: Style.font.body
                                        color: Color.menu.text
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.refreshTopologies()
                                    }
                                }

                                // Hide Topology Window
                                Rectangle {
                                    width: Style.space(32)
                                    height: Style.space(32)
                                    radius: Style.space(6)
                                    color: "#0fffffff"

                                    Text {
                                        anchors.centerIn: parent
                                        text: "\uf068"
                                        font.family: Style.font.family
                                        font.pixelSize: Style.font.caption
                                        color: Color.menu.text
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.requestClose()
                                    }
                                }

                                // Leave Workspace
                                Rectangle {
                                    width: Style.space(32)
                                    height: Style.space(32)
                                    radius: Style.space(6)
                                    color: "#0fffffff"

                                    Text {
                                        anchors.centerIn: parent
                                        text: "\udb81\ud556"
                                        font.family: Style.font.family
                                        font.pixelSize: Style.font.body
                                        color: Color.menu.text
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: Quickshell.execDetached(["hyprctl", "dispatch", "hl.dsp.workspace.toggle_special(\"clab\")"])
                                    }
                                }
                            }
                        }
                    }

                    // Main View Body
                    Item {
                        width: parent.width
                        height: keyCatcher.height - headerBar.height - parent.spacing

                        // 1. Workspace View
                        WorkspaceView {
                            anchors.fill: parent
                            visible: root.currentTab === "workspace"
                            topology: root.currentTopology
                            shiftHeld: root.shiftHeld
                            onLaunchRequested: function(node, grouped) {
                                root.launchNode(node, grouped);
                            }
                        }

                        // 2. Settings View
                        SettingsView {
                            id: settingsView
                            anchors.fill: parent
                            visible: root.currentTab === "settings"
                            topology: root.currentTopology
                            shiftHeld: root.shiftHeld
                            onSaveRequested: function(map) {
                                root.saveSettings(map);
                            }
                            onLaunchRequested: function(node, grouped) {
                                root.launchNode(node, grouped);
                            }
                        }

                        // Floating Toast Alert
                        Rectangle {
                            visible: root.toastMessage !== ""
                            anchors.top: parent.top
                            anchors.right: parent.right
                            anchors.topMargin: Style.space(10)
                            anchors.rightMargin: Style.space(10)
                            width: toastText.implicitWidth + Style.space(24)
                            height: Style.space(36)
                            radius: Style.cornerRadius
                            color: Color.accent
                            z: 100

                            Text {
                                id: toastText
                                anchors.centerIn: parent
                                text: root.toastMessage
                                font.family: Style.font.family
                                font.pixelSize: Style.font.body
                                font.bold: true
                                color: Color.menu.background
                            }
                        }
                    }
                }
            }
        }
    }
}
