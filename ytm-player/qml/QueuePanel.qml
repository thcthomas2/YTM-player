import QtQuick
import QtQuick.Layouts

Rectangle {
    id: root
    property bool open: false
    property var prefs
    property color accent: "#1ed760"
    z: 10
    width: 330
    height: Math.min(parent.height - 140, 540)
    anchors.verticalCenter: parent.verticalCenter
    x: open ? parent.width - width - 20 : parent.width + 24
    opacity: open ? 1 : 0
    visible: opacity > 0
    Behavior on x { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }
    Behavior on opacity { NumberAnimation { duration: 220 } }
    radius: 20
    color: "#a60b0f14"
    border.color: "#26ffffff"

    ColumnLayout {
        anchors { fill: parent; margins: 14 }
        spacing: 10
        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            Text { text: "Up next"; color: "white"; font.pixelSize: 16; font.bold: true; Layout.fillWidth: true }
            Text { text: "Autoplay"; color: "#b3ffffff"; font.pixelSize: 11 }
            Toggle {
                Layout.preferredWidth: 42; Layout.preferredHeight: 24
                accent: root.accent
                checked: prefs.autoplay
                onToggled: (v) => prefs.autoplay = v
            }
        }
        ListView {
            id: ql
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true; spacing: 2
            model: backend.queue
            onCountChanged: positionViewAtIndex(Math.max(0, backend.queueIndex), ListView.Beginning)
            Connections {
                target: backend
                function onQueueIndexChanged() { ql.positionViewAtIndex(Math.max(0, backend.queueIndex), ListView.Center) }
            }
            delegate: Rectangle {
                readonly property bool current: index === backend.queueIndex
                width: ListView.view.width; height: 52; radius: 12
                color: current ? "#2effffff" : (hov.hovered ? "#1fffffff" : "transparent")
                Behavior on color { ColorAnimation { duration: 120 } }
                HoverHandler { id: hov }
                TapHandler { onTapped: backend.playQueueItem(index) }
                Row {
                    anchors { fill: parent; margins: 6 }
                    spacing: 10
                    Image { width: 40; height: 40; source: modelData.thumb; fillMode: Image.PreserveAspectCrop; asynchronous: true }
                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 52
                        Text { width: parent.width; text: modelData.title; color: parent.parent.parent.current ? root.accent : "white"; font.pixelSize: 13; elide: Text.ElideRight }
                        Text { width: parent.width; text: modelData.artist; color: "#99ffffff"; font.pixelSize: 11; elide: Text.ElideRight }
                    }
                }
            }
        }
        Text {
            visible: backend.queue.length === 0
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            text: "Nothing queued yet. Play a song and similar ones will line up here."
            color: "#80ffffff"; font.pixelSize: 12
        }
    }
}
