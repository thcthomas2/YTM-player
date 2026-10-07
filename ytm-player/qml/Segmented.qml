import QtQuick

Rectangle {
    id: root
    property var options: []          // [{label, value}]
    property string current: ""
    signal picked(string value)
    implicitHeight: 26
    implicitWidth: row.width + 8
    radius: 13
    color: "#22ffffff"
    Row {
        id: row
        anchors.centerIn: parent
        spacing: 2
        Repeater {
            model: root.options
            delegate: Rectangle {
                width: lbl.implicitWidth + 24; height: 20; radius: 10
                color: root.current === modelData.value ? "#40ffffff" : "transparent"
                Behavior on color { ColorAnimation { duration: 150 } }
                Text { id: lbl; anchors.centerIn: parent; text: modelData.label; color: "white"; font.pixelSize: 11 }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.picked(modelData.value) }
            }
        }
    }
}
