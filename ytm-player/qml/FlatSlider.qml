import QtQuick

Item {
    id: root
    property real value: 0.5        // 0..1
    property real from: 0
    property real to: 1
    property color accent: "#ff9a3c"
    property color trackColor: "#3a3a3a"
    signal moved(real value)

    implicitHeight: 24
    height: implicitHeight

    Rectangle {
        id: bg
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width
        height: 6
        radius: height / 2
        color: root.trackColor
    }

    Rectangle {
        id: fill
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        height: 6
        radius: height / 2
        width: bg.width * ((root.value - root.from) / (root.to - root.from))
        color: root.accent
        Behavior on color { ColorAnimation { duration: 160 } }
    }

    Rectangle {
        id: handle
        width: 16; height: 16
        radius: 8
        color: "white"
        anchors.verticalCenter: parent.verticalCenter
        x: fill.width - width / 2
    }

    MouseArea {
        anchors.fill: parent
        anchors.margins: -8
        onPositionChanged: (mouse) => {
            if (pressed) {
                let ratio = Math.max(0, Math.min(1, mouse.x / bg.width))
                root.value = root.from + ratio * (root.to - root.from)
                root.moved(root.value)
            }
        }
        onPressed: (mouse) => {
            let ratio = Math.max(0, Math.min(1, mouse.x / bg.width))
            root.value = root.from + ratio * (root.to - root.from)
            root.moved(root.value)
        }
    }
}
