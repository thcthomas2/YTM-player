import QtQuick
import QtQuick.Effects

// Slowly drifting, blurred colour blobs that swell with the bass (stand-in for a shader backdrop).
Item {
    id: root
    property color tint: "#ffffff"
    property real reactivity: 0.3
    property real bass: 0
    property bool playing: false
    clip: true

    Item {
        id: field
        width: root.width / 4
        height: root.height / 4
        scale: 4
        transformOrigin: Item.TopLeft
        layer.enabled: true
        layer.smooth: true
        layer.effect: MultiEffect { blurEnabled: true; blurMax: 48; blur: 0.8 }

        Repeater {
            model: 5
            delegate: Rectangle {
                id: blob
                readonly property real bx: [0.15, 0.8, 0.5, 0.05, 0.9][index]
                readonly property real by: [0.25, 0.2, 0.85, 0.9, 0.75][index]
                property real dx: 0
                property real dy: 0
                width: field.width * 0.6; height: width; radius: width / 2
                x: field.width * bx - width / 2 + dx
                y: field.height * by - height / 2 + dy
                color: index % 2 === 0 ? root.tint : Qt.lighter(root.tint, 1.3)
                Behavior on color { ColorAnimation { duration: 800 } }
                opacity: 0.75 + Math.min(1, root.bass) * root.reactivity * 0.25
                Behavior on opacity { NumberAnimation { duration: 110 } }
                scale: 1 + Math.min(1, root.bass) * root.reactivity * 0.35
                Behavior on scale { NumberAnimation { duration: 110 } }
                SequentialAnimation on dx {
                    loops: Animation.Infinite; running: root.playing
                    NumberAnimation { to: field.width * 0.12; duration: 7000 + index * 1300; easing.type: Easing.InOutSine }
                    NumberAnimation { to: -field.width * 0.12; duration: 7000 + index * 1300; easing.type: Easing.InOutSine }
                }
                SequentialAnimation on dy {
                    loops: Animation.Infinite; running: root.playing
                    NumberAnimation { to: -field.height * 0.14; duration: 8200 + index * 1100; easing.type: Easing.InOutSine }
                    NumberAnimation { to: field.height * 0.14; duration: 8200 + index * 1100; easing.type: Easing.InOutSine }
                }
            }
        }
    }
}
