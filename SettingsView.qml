import QtQuick
import QtQuick.Controls
import qs.Commons
import qs.Ui

Item {
    id: root

    property var topology: null
    property bool shiftHeld: false
    signal saveRequested(var settingsMap)
    signal launchRequested(var node, bool grouped)

    Keys.priority: Keys.BeforeItem
    Keys.onPressed: function(event) {
        if (event.key === Qt.Key_Shift) {
            root.shiftHeld = true;
        }
    }
    Keys.onReleased: function(event) {
        if (event.key === Qt.Key_Shift) {
            root.shiftHeld = false;
        }
    }

    ListModel {
        id: deviceModel
    }

    property string currentLabName: ""

    function syncModel(force) {
        if (!topology || !topology.nodes) {
            deviceModel.clear();
            currentLabName = "";
            return;
        }

        // If it's the exact same lab and not forced, preserve user input!
        if (!force && currentLabName === topology.name && deviceModel.count === topology.nodes.length) {
            return;
        }

        currentLabName = topology.name;
        deviceModel.clear();
        for (var i = 0; i < topology.nodes.length; i++) {
            var n = topology.nodes[i];
            deviceModel.append({
                name: n.name || "",
                kind: n.kind || "",
                image: n.image || "",
                ipv4: n.ipv4 || "",
                state: n.state || "running",
                app: n.app || n.default_app || "terminal",
                command: n.command || n.default_command || "",
                url: n.url || n.default_url || "",
                default_app: n.default_app || "terminal",
                default_command: n.default_command || "",
                default_url: n.default_url || ""
            });
        }
    }

    function forceReload() {
        syncModel(true);
    }

    onTopologyChanged: syncModel(false)
    Component.onCompleted: syncModel(true)

    function saveAll() {
        if (!root.topology) return;
        var map = {};
        map[root.topology.name] = {};
        for (var i = 0; i < deviceModel.count; i++) {
            var it = deviceModel.get(i);
            map[root.topology.name][it.name] = {
                app: it.app,
                command: it.command,
                url: it.url
            };
        }
        root.saveRequested(map);
    }

    function resetAll() {
        for (var i = 0; i < deviceModel.count; i++) {
            var it = deviceModel.get(i);
            it.app = it.default_app;
            it.command = it.default_command;
            it.url = it.default_url;
        }
    }

    Column {
        anchors.fill: parent
        spacing: Style.space(10)

        // Subheader
        Rectangle {
            width: parent.width
            height: Style.space(32)
            color: "transparent"

            Row {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: Style.space(8)

                Text {
                    text: "\udb81\ude93 Device Settings for: " + (root.topology ? root.topology.name : "N/A")
                    font.family: Style.font.family
                    font.pixelSize: Style.font.title
                    font.bold: true
                    color: Color.menu.text
                }

                Text {
                    text: "— Configure click action (terminal command or browser URL) for each device"
                    font.family: Style.font.family
                    font.pixelSize: Style.font.body
                    color: Color.menu.text
                    opacity: 0.6
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }

        // Table Header
        Rectangle {
            width: parent.width
            height: Style.space(30)
            radius: Style.cornerRadius
            color: "#0affffff"

            Row {
                anchors.fill: parent
                anchors.leftMargin: Style.space(12)
                anchors.rightMargin: Style.space(12)
                spacing: Style.space(12)

                Text {
                    width: Style.space(180)
                    text: "DEVICE"
                    font.family: Style.font.family
                    font.pixelSize: Style.font.caption
                    font.bold: true
                    color: Color.menu.text
                    opacity: 0.6
                    anchors.verticalCenter: parent.verticalCenter
                }

                Text {
                    width: Style.space(190)
                    text: "DEFAULT APPLICATION"
                    font.family: Style.font.family
                    font.pixelSize: Style.font.caption
                    font.bold: true
                    color: Color.menu.text
                    opacity: 0.6
                    anchors.verticalCenter: parent.verticalCenter
                }

                Text {
                    width: parent.width - Style.space(180) - Style.space(190) - Style.space(170) - Style.space(36)
                    text: "COMMAND / URL TARGET"
                    font.family: Style.font.family
                    font.pixelSize: Style.font.caption
                    font.bold: true
                    color: Color.menu.text
                    opacity: 0.6
                    anchors.verticalCenter: parent.verticalCenter
                }

                Text {
                    width: Style.space(170)
                    text: "ACTIONS"
                    font.family: Style.font.family
                    font.pixelSize: Style.font.caption
                    font.bold: true
                    color: Color.menu.text
                    opacity: 0.6
                    anchors.verticalCenter: parent.verticalCenter
                    horizontalAlignment: Text.AlignRight
                }
            }
        }

        // Scrollable Devices List
        ListView {
            id: deviceList
            width: parent.width
            height: parent.height - Style.space(32) - Style.space(30) - footerControls.height - parent.spacing * 3
            model: deviceModel
            clip: true
            spacing: Style.space(6)
            boundsBehavior: Flickable.StopAtBounds

            delegate: Rectangle {
                id: rowRect
                width: deviceList.width
                height: Style.space(52)
                radius: Style.cornerRadius
                color: "#1a1d27"
                border.width: 1
                border.color: Util.alpha(Color.menu.border, 0.4)

                Row {
                    anchors.fill: parent
                    anchors.leftMargin: Style.space(12)
                    anchors.rightMargin: Style.space(12)
                    spacing: Style.space(12)

                    // 1. Device Info (Name, Kind, IP)
                    Item {
                        width: Style.space(180)
                        height: parent.height

                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: Style.space(2)

                            Row {
                                spacing: Style.space(6)

                                Rectangle {
                                    width: Style.space(7)
                                    height: Style.space(7)
                                    radius: width / 2
                                    color: model.state === "running" ? "#34c759" : "#ff3b30"
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                Text {
                                    text: model.name
                                    font.family: Style.font.family
                                    font.pixelSize: Style.font.body
                                    font.bold: true
                                    color: Color.menu.text
                                }
                            }

                            Text {
                                text: (model.kind ? model.kind : "node") + (model.ipv4 ? (" • " + model.ipv4) : "")
                                font.family: Style.font.family
                                font.pixelSize: Style.font.caption
                                color: Color.menu.text
                                opacity: 0.65
                                elide: Text.ElideRight
                                width: Style.space(170)
                            }
                        }
                    }

                    // 2. Application Switcher (Terminal vs Browser)
                    Item {
                        width: Style.space(190)
                        height: parent.height

                        Row {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: Style.space(4)

                            // Terminal Button
                            Rectangle {
                                width: Style.space(90)
                                height: Style.space(30)
                                radius: Style.space(5)
                                color: model.app === "terminal" ? Color.accent : "#12ffffff"
                                border.width: 1
                                border.color: model.app === "terminal" ? Color.accent : Util.alpha(Color.menu.border, 0.5)

                                Row {
                                    anchors.centerIn: parent
                                    spacing: Style.space(4)
                                    Text {
                                        text: "\udb81\udfb7"
                                        font.family: Style.font.family
                                        font.pixelSize: Style.font.caption
                                        color: model.app === "terminal" ? Color.menu.background : Color.menu.text
                                    }
                                    Text {
                                        text: "Terminal"
                                        font.family: Style.font.family
                                        font.pixelSize: Style.font.caption
                                        font.bold: model.app === "terminal"
                                        color: model.app === "terminal" ? Color.menu.background : Color.menu.text
                                    }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: model.app = "terminal"
                                }
                            }

                            // Browser Button
                            Rectangle {
                                width: Style.space(90)
                                height: Style.space(30)
                                radius: Style.space(5)
                                color: model.app === "browser" ? Color.accent : "#12ffffff"
                                border.width: 1
                                border.color: model.app === "browser" ? Color.accent : Util.alpha(Color.menu.border, 0.5)

                                Row {
                                    anchors.centerIn: parent
                                    spacing: Style.space(4)
                                    Text {
                                        text: "\udb81\uddbf"
                                        font.family: Style.font.family
                                        font.pixelSize: Style.font.caption
                                        color: model.app === "browser" ? Color.menu.background : Color.menu.text
                                    }
                                    Text {
                                        text: "Browser"
                                        font.family: Style.font.family
                                        font.pixelSize: Style.font.caption
                                        font.bold: model.app === "browser"
                                        color: model.app === "browser" ? Color.menu.background : Color.menu.text
                                    }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: model.app = "browser"
                                }
                            }
                        }
                    }

                    // 3. Command / URL Target Input
                    Item {
                        width: parent.width - Style.space(180) - Style.space(190) - Style.space(170) - Style.space(36)
                        height: parent.height

                        TextField {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width
                            text: model.app === "browser" ? model.url : model.command
                            placeholderText: model.app === "browser" ? model.default_url : model.default_command
                            font.family: Style.font.family
                            font.pixelSize: Style.font.body
                            onTextEdited: {
                                if (model.app === "browser") {
                                    model.url = text;
                                } else {
                                    model.command = text;
                                }
                            }
                        }
                    }

                    // 4. Row Action Buttons (Reset, Test Launch)
                    Item {
                        width: Style.space(170)
                        height: parent.height

                        Row {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: Style.space(6)

                            // Reset button
                            Rectangle {
                                width: Style.space(68)
                                height: Style.space(28)
                                radius: Style.space(5)
                                color: "#0fffffff"
                                border.width: 1
                                border.color: Util.alpha(Color.menu.border, 0.5)

                                Text {
                                    anchors.centerIn: parent
                                    text: "Reset"
                                    font.family: Style.font.family
                                    font.pixelSize: Style.font.caption
                                    color: Color.menu.text
                                    opacity: 0.8
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        model.app = model.default_app;
                                        model.command = model.default_command;
                                        model.url = model.default_url;
                                    }
                                }
                            }

                            // Test launch button
                            Rectangle {
                                width: Style.space(80)
                                height: Style.space(28)
                                radius: Style.space(5)
                                color: Util.alpha(Color.accent, 0.18)
                                border.width: 1
                                border.color: Color.accent

                                Row {
                                    anchors.centerIn: parent
                                    spacing: Style.space(4)

                                    Text {
                                        text: "\udb80\udc0a" // play/run
                                        font.family: Style.font.family
                                        font.pixelSize: Style.font.caption
                                        color: Color.accent
                                    }

                                    Text {
                                        text: "Test"
                                        font.family: Style.font.family
                                        font.pixelSize: Style.font.caption
                                        font.bold: true
                                        color: Color.accent
                                    }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onPressed: function(mouse) {
                                        if ((mouse.modifiers & Qt.ShiftModifier) !== 0) {
                                            root.shiftHeld = true;
                                        }
                                    }
                                    onClicked: function(mouse) {
                                        var isShift = ((mouse.modifiers & Qt.ShiftModifier) !== 0) || root.shiftHeld;
                                        root.shiftHeld = false;
                                        root.launchRequested({
                                            name: model.name,
                                            app: model.app,
                                            command: model.command,
                                            url: model.url
                                        }, isShift);
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        // Bottom Footer Controls
        Rectangle {
            id: footerControls
            width: parent.width
            height: Style.space(40)
            color: "transparent"

            Row {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: Style.space(6)

                Text {
                    text: "\udb80\udfd6 SR Linux defaults to SSH • FRR defaults to vtysh"
                    font.family: Style.font.family
                    font.pixelSize: Style.font.caption
                    color: Color.menu.text
                    opacity: 0.55
                }
            }

            Row {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: Style.space(8)

                // Reset all
                Rectangle {
                    width: Style.space(140)
                    height: Style.space(34)
                    radius: Style.cornerRadius
                    color: "#14ffffff"
                    border.width: 1
                    border.color: Util.alpha(Color.menu.border, 0.6)

                    Row {
                        anchors.centerIn: parent
                        spacing: Style.space(5)

                        Text {
                            text: "\udb81\udc50"
                            font.family: Style.font.family
                            font.pixelSize: Style.font.body
                            color: Color.menu.text
                        }

                        Text {
                            text: "Reset All Defaults"
                            font.family: Style.font.family
                            font.pixelSize: Style.font.caption
                            color: Color.menu.text
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.resetAll()
                    }
                }

                // Save button
                Rectangle {
                    width: Style.space(130)
                    height: Style.space(34)
                    radius: Style.cornerRadius
                    color: Color.accent

                    Row {
                        anchors.centerIn: parent
                        spacing: Style.space(5)

                        Text {
                            text: "\udb81\ud12c"
                            font.family: Style.font.family
                            font.pixelSize: Style.font.body
                            color: Color.menu.background
                        }

                        Text {
                            text: "Save Settings"
                            font.family: Style.font.family
                            font.pixelSize: Style.font.body
                            font.bold: true
                            color: Color.menu.background
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.saveAll()
                    }
                }
            }
        }
    }
}
