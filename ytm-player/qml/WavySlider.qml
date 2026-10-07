import QtQuick

// Pixel-style progress: wavy while playing, flat when paused, pill-shaped handle.
Item {
    id: root
    property real from: 0
    property real to: 1
    property real value: 0
    property color accent: "#1ed760"
    property bool playing: false
    property bool dragging: false
    property real dragValue: 0
    readonly property real shown: dragging ? dragValue : value
    property real amp: playing ? 3.2 : 0
    property real phase: 0
    signal seekRequested(real v)
    implicitHeight: 24

    Behavior on amp { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }
    NumberAnimation on phase {
        from: 0; to: Math.PI * 2; duration: 1300; loops: Animation.Infinite
        running: root.visible && (root.playing || root.amp > 0.05)
    }
    onShownChanged: cv.requestPaint()
    onToChanged: cv.requestPaint()
    onAmpChanged: cv.requestPaint()
    onPhaseChanged: cv.requestPaint()
    onAccentChanged: cv.requestPaint()
    onWidthChanged: cv.requestPaint()

    Canvas {
        id: cv
        anchors.fill: parent
        onPaint: {
            var c = getContext("2d")
            c.clearRect(0, 0, width, height)
            var span = root.to - root.from
            var frac = span > 0 ? Math.max(0, Math.min(1, (root.shown - root.from) / span)) : 0
            var px = Math.max(3, Math.min(width - 3, frac * width))
            var cy = height / 2
            c.lineCap = "round"
            c.lineJoin = "round"
            c.lineWidth = 4
            // remaining track
            c.strokeStyle = "rgba(255,255,255,0.28)"
            if (px + 7 < width - 2) { c.beginPath(); c.moveTo(px + 7, cy); c.lineTo(width - 2, cy); c.stroke() }
            // played part
            c.strokeStyle = Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 1)
            c.beginPath()
            var end = Math.max(3, px - 7)
            c.moveTo(3, cy)
            for (var x = 3; x <= end; x += 2) c.lineTo(x, cy + Math.sin(x / 9 - root.phase) * root.amp)
            c.stroke()
            // handle
            c.lineWidth = 5
            c.beginPath(); c.moveTo(px, cy - 9); c.lineTo(px, cy + 9); c.stroke()
        }
    }
    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        function valueAt(x) { return root.from + Math.max(0, Math.min(1, x / width)) * (root.to - root.from) }
        onPressed: (m) => { root.dragging = true; root.dragValue = valueAt(m.x) }
        onPositionChanged: (m) => { if (pressed) root.dragValue = valueAt(m.x) }
        onReleased: { root.seekRequested(root.dragValue); root.dragging = false }
    }
}
