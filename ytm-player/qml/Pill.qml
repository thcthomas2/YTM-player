import QtQuick

Rectangle {
    id: root
    property string text: ""
    property bool primary: false
    property color fill: "#f2ffffff"
    signal clicked()
    implicitWidth: lbl.implicitWidth + 28
    implicitHeight: 28
    radius: 14
    color: primary ? (ma.containsMouse ? Qt.lighter(fill, 1.1) : fill) : (ma.containsMouse ? "#40ffffff" : "#26ffffff")
    Behavior on color { ColorAnimation { duration: 120 } }
    Text { id: lbl; anchors.centerIn: parent; text: root.text; color: root.primary ? "#111111" : "white"; font.pixelSize: 12 }
    MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.clicked() }
}
