import QtQuick

Item {
    id: root
    property bool checked: false
    property color accent: "#ff9a3c"
    property color trackOff: "#3a3a3a"
    property color thumbColor: "white"
    signal toggled(bool value)

    implicitWidth: 52
    implicitHeight: 30
    width: implicitWidth
    height: implicitHeight

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: root.checked ? root.accent : root.trackOff
        Behavior on color { ColorAnimation { duration: 160 } }
    }

    Rectangle {
        width: 24; height: 24
        radius: 12
        color: root.thumbColor
        y: 3
        x: root.checked ? root.width - width - 3 : 3
        Behavior on x { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            root.checked = !root.checked
            root.toggled(root.checked)
        }
    }
}
