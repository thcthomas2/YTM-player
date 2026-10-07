import QtQuick

Item {
    id: btn
    property string kind: "play"
    property color col: "white"
    property real hoverScale: 1.12
    signal clicked()
    implicitWidth: 28
    implicitHeight: 28

    Glyph {
        anchors.fill: parent
        kind: btn.kind
        col: btn.col
        scale: ma.pressed ? 0.88 : (ma.containsMouse ? btn.hoverScale : 1.0)
        Behavior on scale { NumberAnimation { duration: 110; easing.type: Easing.OutQuad } }
    }
    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: btn.clicked()
    }
}
