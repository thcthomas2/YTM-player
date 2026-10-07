import QtQuick

Canvas {
    id: g
    property string kind: "play"
    property color col: "white"
    onKindChanged: requestPaint()
    onColChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
    onPaint: {
        var c = getContext("2d")
        var w = width, h = height
        c.clearRect(0, 0, w, h)
        c.fillStyle = col
        c.strokeStyle = col
        c.lineWidth = Math.max(1.5, w * 0.09)
        c.lineCap = "round"
        c.lineJoin = "round"
        function tri(x1, y1, x2, y2, x3, y3) {
            c.beginPath(); c.moveTo(w * x1, h * y1); c.lineTo(w * x2, h * y2); c.lineTo(w * x3, h * y3); c.closePath(); c.fill()
        }
        function line(x1, y1, x2, y2) {
            c.beginPath(); c.moveTo(w * x1, h * y1); c.lineTo(w * x2, h * y2); c.stroke()
        }
        switch (kind) {
        case "play": tri(.32, .2, .82, .5, .32, .8); break
        case "pause": c.fillRect(w * .28, h * .2, w * .15, h * .6); c.fillRect(w * .57, h * .2, w * .15, h * .6); break
        case "next": tri(.2, .22, .68, .5, .2, .78); c.fillRect(w * .72, h * .22, w * .1, h * .56); break
        case "prev": tri(.8, .22, .32, .5, .8, .78); c.fillRect(w * .18, h * .22, w * .1, h * .56); break
        case "shuffle":
            c.beginPath()
            c.moveTo(w * .12, h * .3); c.lineTo(w * .4, h * .3); c.lineTo(w * .6, h * .7); c.lineTo(w * .78, h * .7)
            c.moveTo(w * .12, h * .7); c.lineTo(w * .4, h * .7); c.lineTo(w * .6, h * .3); c.lineTo(w * .78, h * .3)
            c.stroke()
            tri(.92, .3, .76, .18, .76, .42); tri(.92, .7, .76, .58, .76, .82)
            break
        case "repeat":
            c.beginPath(); c.arc(w * .5, h * .5, w * .3, 0.25 * Math.PI, 1.75 * Math.PI, false); c.stroke()
            tri(.82, .14, .82, .42, .6, .29)
            break
        case "search":
            c.beginPath(); c.arc(w * .44, h * .44, w * .22, 0, 2 * Math.PI); c.stroke()
            line(.6, .6, .82, .82)
            break
        case "lyrics": line(.2, .3, .8, .3); line(.2, .5, .65, .5); line(.2, .7, .75, .7); break
        case "viz": line(.25, .7, .25, .4); line(.42, .8, .42, .2); line(.58, .65, .58, .35); line(.75, .75, .75, .45); break
        case "gear":
            c.beginPath(); c.arc(w * .5, h * .5, w * .17, 0, 2 * Math.PI); c.stroke()
            for (var i = 0; i < 8; i++) {
                var a = i * Math.PI / 4
                line(.5 + .28 * Math.cos(a), .5 + .28 * Math.sin(a), .5 + .4 * Math.cos(a), .5 + .4 * Math.sin(a))
            }
            break
        case "volume":
            c.beginPath(); c.moveTo(w * .15, h * .4); c.lineTo(w * .32, h * .4); c.lineTo(w * .52, h * .22)
            c.lineTo(w * .52, h * .78); c.lineTo(w * .32, h * .6); c.lineTo(w * .15, h * .6); c.closePath(); c.fill()
            c.beginPath(); c.arc(w * .52, h * .5, w * .22, -0.7, 0.7); c.stroke()
            break
        case "library": line(.22, .22, .22, .78); line(.4, .22, .4, .78); line(.58, .3, .76, .76); break
        case "queue": line(.15, .3, .58, .3); line(.15, .5, .58, .5); line(.15, .7, .42, .7); tri(.68, .42, .68, .86, .88, .64); break
        case "close": line(.25, .25, .75, .75); line(.75, .25, .25, .75); break
        }
    }
}
