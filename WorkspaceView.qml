import QtQuick
import QtQuick.Controls
import qs.Commons
import qs.Ui

Item {
    id: root

    property var topology: null
    property string hoveredNode: ""
    signal launchRequested(var node)

    // Node coordinate mapper
    function getNodePos(nodeName) {
        if (!topology || !topology.nodes || topology.nodes.length === 0) {
            return { x: canvasArea.width / 2, y: canvasArea.height / 2 };
        }
        var node = null;
        for (var i = 0; i < topology.nodes.length; i++) {
            if (topology.nodes[i].name === nodeName) {
                node = topology.nodes[i];
                break;
            }
        }
        if (!node) {
            return { x: canvasArea.width / 2, y: canvasArea.height / 2 };
        }

        var bounds = topology.bounds || { min_x: 0, max_x: 1000, min_y: 0, max_y: 600 };
        var padX = Style.space(90);
        var padY = Style.space(70);
        var availW = Math.max(100, canvasArea.width - 2 * padX);
        var availH = Math.max(100, canvasArea.height - 2 * padY);

        var spanX = bounds.max_x - bounds.min_x;
        var spanY = bounds.max_y - bounds.min_y;
        if (spanX <= 0) spanX = 1;
        if (spanY <= 0) spanY = 1;

        var scaleX = availW / spanX;
        var scaleY = availH / spanY;
        var scale = Math.min(scaleX, scaleY);

        var graphW = spanX * scale;
        var graphH = spanY * scale;

        var offX = (canvasArea.width - graphW) / 2;
        var offY = (canvasArea.height - graphH) / 2;

        var nx = offX + (node.x - bounds.min_x) * scale;
        var ny = offY + (node.y - bounds.min_y) * scale;

        return { x: nx, y: ny };
    }

    onHoveredNodeChanged: linkCanvas.requestPaint()
    onTopologyChanged: Qt.callLater(function() { linkCanvas.requestPaint(); })

    // Empty state
    Column {
        anchors.centerIn: parent
        spacing: Style.space(12)
        visible: !root.topology || !root.topology.nodes || root.topology.nodes.length === 0

        Text {
            text: "\uf0e8"
            color: Color.menu.text
            opacity: 0.4
            font.family: Style.font.family
            font.pixelSize: Style.space(64)
            horizontalAlignment: Text.AlignHCenter
            width: parent.width
        }

        Text {
            text: "No active Containerlab topology found"
            color: Color.menu.text
            font.family: Style.font.family
            font.pixelSize: Style.font.title
            font.bold: true
            horizontalAlignment: Text.AlignHCenter
            width: parent.width
        }

        Text {
            text: "Deploy a topology with 'containerlab deploy -t <file>' to see it here."
            color: Color.menu.text
            opacity: 0.7
            font.family: Style.font.family
            font.pixelSize: Style.font.body
            horizontalAlignment: Text.AlignHCenter
            width: parent.width
        }
    }

    // Active workspace content
    Column {
        anchors.fill: parent
        spacing: Style.space(8)
        visible: root.topology && root.topology.nodes && root.topology.nodes.length > 0

        // Topology Canvas Box
        Rectangle {
            id: canvasArea
            width: parent.width
            height: parent.height - footerBar.height - parent.spacing
            radius: Style.cornerRadius
            color: "#161922"
            border.width: 1
            border.color: Util.alpha(Color.menu.border, 0.4)
            clip: true

            onWidthChanged: linkCanvas.requestPaint()
            onHeightChanged: linkCanvas.requestPaint()

            // Subtle blueprint dot pattern
            Canvas {
                id: bgGrid
                anchors.fill: parent
                onPaint: {
                    var ctx = getContext("2d");
                    ctx.clearRect(0, 0, width, height);
                    ctx.fillStyle = "rgba(255, 255, 255, 0.03)";
                    var step = 32;
                    for (var x = 16; x < width; x += step) {
                        for (var y = 16; y < height; y += step) {
                            ctx.beginPath();
                            ctx.arc(x, y, 1, 0, 2 * Math.PI);
                            ctx.fill();
                        }
                    }
                }
            }

            // Connection Link Lines
            Canvas {
                id: linkCanvas
                anchors.fill: parent

                onPaint: {
                    var ctx = getContext("2d");
                    ctx.clearRect(0, 0, width, height);
                    if (!root.topology || !root.topology.links) return;

                    var links = root.topology.links;
                    for (var i = 0; i < links.length; i++) {
                        var l = links[i];
                        var p1 = root.getNodePos(l.a_node);
                        var p2 = root.getNodePos(l.z_node);
                        var isHighlighted = (root.hoveredNode !== "" && (root.hoveredNode === l.a_node || root.hoveredNode === l.z_node));

                        ctx.beginPath();
                        ctx.moveTo(p1.x, p1.y);
                        ctx.lineTo(p2.x, p2.y);
                        ctx.lineWidth = isHighlighted ? 3.0 : 1.5;
                        ctx.strokeStyle = isHighlighted ? Color.accent : "rgba(120, 140, 175, 0.45)";
                        ctx.stroke();

                        // Draw interface names if link is highlighted
                        if (isHighlighted) {
                            ctx.font = "10px sans-serif";
                            ctx.fillStyle = Color.accent;

                            // Point near A (25% along link)
                            var ax = p1.x + (p2.x - p1.x) * 0.22;
                            var ay = p1.y + (p2.y - p1.y) * 0.22 - 6;
                            ctx.fillText(l.a_intf, ax, ay);

                            // Point near Z (75% along link)
                            var zx = p1.x + (p2.x - p1.x) * 0.78;
                            var zy = p1.y + (p2.y - p1.y) * 0.78 - 6;
                            ctx.fillText(l.z_intf, zx, zy);
                        }
                    }
                }
            }

            // Interactive Node Cards
            Repeater {
                model: root.topology ? root.topology.nodes : []

                Item {
                    id: nodeItem
                    required property var modelData
                    readonly property var pos: root.getNodePos(modelData.name)
                    readonly property bool isHovered: root.hoveredNode === modelData.name

                    width: Style.space(136)
                    height: Style.space(68)
                    x: pos.x - width / 2
                    y: pos.y - height / 2
                    z: isHovered ? 10 : 2

                    Rectangle {
                        anchors.fill: parent
                        radius: Style.cornerRadius
                        color: nodeItem.isHovered ? "#2b3040" : "#1e222d"
                        border.width: nodeItem.isHovered ? 2 : 1
                        border.color: nodeItem.isHovered ? Color.accent : Util.alpha(Color.menu.border, 0.6)

                        Column {
                            anchors.fill: parent
                            anchors.margins: Style.space(6)
                            spacing: Style.space(3)

                            // Top row: status dot, device icon, node name
                            Row {
                                width: parent.width
                                spacing: Style.space(5)

                                Rectangle {
                                    width: Style.space(7)
                                    height: Style.space(7)
                                    radius: width / 2
                                    color: modelData.state === "running" ? "#34c759" : "#ff3b30"
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                Text {
                                    text: {
                                        var nl = (modelData.name || "").toLowerCase();
                                        if (nl.indexOf("spine") !== -1 || nl.indexOf("router") !== -1) return "\udb84\udc9b"; // router
                                        if (nl.indexOf("leaf") !== -1 || nl.indexOf("switch") !== -1) return "\udb81\ude8b"; // switch
                                        return "\udb81\udfb7"; // terminal/host
                                    }
                                    font.family: Style.font.family
                                    font.pixelSize: Style.font.body
                                    color: nodeItem.isHovered ? Color.accent : Color.menu.text
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                Text {
                                    text: modelData.name
                                    font.family: Style.font.family
                                    font.pixelSize: Style.font.body
                                    font.bold: true
                                    color: Color.menu.text
                                    elide: Text.ElideRight
                                    width: parent.width - Style.space(35)
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }

                            // Subtitle: Kind and IP
                            Text {
                                text: (modelData.ipv4 || modelData.kind || "device")
                                font.family: Style.font.family
                                font.pixelSize: Style.font.caption
                                color: Color.menu.text
                                opacity: 0.65
                                elide: Text.ElideRight
                                width: parent.width
                            }

                            // Bottom pill: App action preview
                            Rectangle {
                                width: parent.width
                                height: Style.space(18)
                                radius: Style.space(4)
                                color: nodeItem.isHovered ? "#385e81ac" : "#0dffffff"

                                Row {
                                    anchors.centerIn: parent
                                    spacing: Style.space(4)

                                    Text {
                                        text: modelData.app === "browser" ? "\udb81\uddbf" : "\udb81\udfb7"
                                        font.family: Style.font.family
                                        font.pixelSize: Style.font.caption
                                        color: nodeItem.isHovered ? Color.accent : Color.menu.text
                                        anchors.verticalCenter: parent.verticalCenter
                                    }

                                    Text {
                                        text: {
                                            if (modelData.app === "browser") return "Browser";
                                            var cmd = modelData.command || "";
                                            if (cmd.indexOf("vtysh") !== -1) return "vtysh";
                                            if (cmd.indexOf("ssh") !== -1) return "ssh";
                                            if (cmd.indexOf("bash") !== -1) return "bash";
                                            return "terminal";
                                        }
                                        font.family: Style.font.family
                                        font.pixelSize: Style.font.caption
                                        color: nodeItem.isHovered ? Color.accent : Color.menu.text
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: root.hoveredNode = modelData.name
                            onExited: if (root.hoveredNode === modelData.name) root.hoveredNode = ""
                            onClicked: root.launchRequested(modelData)
                        }
                    }
                }
            }
        }

        // Bottom Footer Bar
        Rectangle {
            id: footerBar
            width: parent.width
            height: Style.space(28)
            radius: Style.cornerRadius
            color: "transparent"

            Row {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: Style.space(16)

                Text {
                    text: "\uf0e8 " + (root.topology ? root.topology.name : "") + " (" + (root.topology ? root.topology.node_count : 0) + " nodes, " + (root.topology ? root.topology.link_count : 0) + " links)"
                    font.family: Style.font.family
                    font.pixelSize: Style.font.caption
                    font.bold: true
                    color: Color.menu.text
                    opacity: 0.85
                }

                Text {
                    text: root.topology ? root.topology.path : ""
                    font.family: Style.font.family
                    font.pixelSize: Style.font.caption
                    color: Color.menu.text
                    opacity: 0.5
                    elide: Text.ElideMiddle
                    width: Style.space(350)
                }
            }

            Row {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: Style.space(6)

                Text {
                    text: "\udb81\udcc4 Click node to launch default action • Settings to customize"
                    font.family: Style.font.family
                    font.pixelSize: Style.font.caption
                    color: Color.accent
                    opacity: 0.9
                }
            }
        }
    }
}
