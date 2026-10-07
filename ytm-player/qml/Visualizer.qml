import QtQuick

Item {
    id: root

    property string style: "normal"     // "normal" | "circular"
    property string shape: "bars"       // "bars" | "wave"
    property var spectrum: []           // array of floats 0..1 from backend
    property color accent: prefs.accent
    property real sensitivity: 1.0

    property int barCount: 48
    property var targetLevels: new Array(barCount).fill(0)
    property var smoothedLevels: new Array(barCount).fill(0)

    function resample(src, count) {
        if (!src || src.length === 0) return new Array(count).fill(0)
            var out = new Array(count)
            for (var i = 0; i < count; i++) {
                var pos = (i / count) * src.length
                var idx = Math.min(src.length - 1, Math.floor(pos))
                out[i] = src[idx]
            }
            return out
    }

    onSpectrumChanged: {
        targetLevels = resample(spectrum, barCount)
    }

    Timer {
        interval: 16
        running: true
        repeat: true
        onTriggered: {
            var changed = false
            for (var i = 0; i < root.barCount; i++) {
                var target = (root.targetLevels[i] || 0) * root.sensitivity
                var current = root.smoothedLevels[i] || 0
                var next = target > current
                ? current + (target - current) * 0.6   // fast attack
                : current + (target - current) * 0.12  // slow decay
                if (Math.abs(next - current) > 0.001) changed = true
                    root.smoothedLevels[i] = next
            }
            if (changed) canvas.requestPaint()
        }
    }

    Canvas {
        id: canvas
        anchors.fill: parent

        onPaint: {
            var ctx = getContext("2d")
            ctx.reset()
            ctx.strokeStyle = root.accent
            ctx.fillStyle = root.accent

            if (root.style === "circular")
                drawCircular(ctx)
                else
                    drawNormal(ctx)
        }

        function drawCircular(ctx) {
            var cx = width / 2
            var cy = height / 2
            var baseRadius = Math.min(width, height) / 2 * 0.72
            var maxExtra = Math.min(width, height) / 2 * 0.24
            var n = root.barCount

            if (root.shape === "bars") {
                for (var i = 0; i < n; i++) {
                    var angle = (i / n) * Math.PI * 2
                    var level = Math.max(0, Math.min(1, root.smoothedLevels[i] || 0))
                    var len = 4 + level * maxExtra
                    var x1 = cx + Math.cos(angle) * baseRadius
                    var y1 = cy + Math.sin(angle) * baseRadius
                    var x2 = cx + Math.cos(angle) * (baseRadius + len)
                    var y2 = cy + Math.sin(angle) * (baseRadius + len)
                    ctx.globalAlpha = 0.55 + level * 0.45
                    ctx.lineWidth = 2
                    ctx.beginPath()
                    ctx.moveTo(x1, y1)
                    ctx.lineTo(x2, y2)
                    ctx.stroke()
                }
            } else {
                ctx.globalAlpha = 0.8
                ctx.lineWidth = 2
                ctx.beginPath()
                for (var j = 0; j <= n; j++) {
                    var idx = j % n
                    var a = (j / n) * Math.PI * 2
                    var lvl = Math.max(0, Math.min(1, root.smoothedLevels[idx] || 0))
                    var r = baseRadius + lvl * maxExtra
                    var px = cx + Math.cos(a) * r
                    var py = cy + Math.sin(a) * r
                    if (j === 0) ctx.moveTo(px, py)
                        else ctx.lineTo(px, py)
                }
                ctx.closePath()
                ctx.stroke()
            }
        }

        function drawNormal(ctx) {
            var n = root.barCount
            var slot = width / n

            if (root.shape === "bars") {
                for (var i = 0; i < n; i++) {
                    var level = Math.max(0, Math.min(1, root.smoothedLevels[i] || 0))
                    var barH = 3 + level * (height * 0.9)
                    var x = i * slot + slot * 0.2
                    var w = slot * 0.6
                    var y = height - barH
                    ctx.globalAlpha = 0.55 + level * 0.45
                    ctx.fillRect(x, y, w, barH)
                }
            } else {
                ctx.globalAlpha = 0.85
                ctx.lineWidth = 2
                ctx.beginPath()
                for (var j = 0; j < n; j++) {
                    var lvl = Math.max(0, Math.min(1, root.smoothedLevels[j] || 0))
                    var px = j * slot + slot / 2
                    var py = height / 2 - lvl * (height * 0.45)
                    if (j === 0) ctx.moveTo(px, py)
                        else ctx.lineTo(px, py)
                }
                ctx.stroke()
            }
        }
    }
}
