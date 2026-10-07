import QtQuick
import QtQuick.Controls.Basic

Rectangle {
    id: root
    property bool open: false
    property color accent: "#1ed760"
    readonly property bool hasList: !!backend.listInfo.id
    readonly property string meta: {
        var t = 0, l = backend.listTracks
        for (var i = 0; i < l.length; i++) t += l[i].duration || 0
        var m = Math.round(t / 60)
        return l.length + " songs  •  " + (m >= 60 ? Math.floor(m / 60) + " hr " + (m % 60) + " min" : m + " min")
    }
    signal signInRequested()
    visible: opacity > 0
    opacity: open ? 1 : 0
    scale: open ? 1 : 0.97
    Behavior on opacity { NumberAnimation { duration: 220 } }
    Behavior on scale { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
    radius: 20
    color: "#b30b0f14"
    border.color: "#26ffffff"
    function fmt(sec) { var s = Math.floor(sec); return Math.floor(s / 60) + ":" + ("0" + (s % 60)).slice(-2) }

    // ---------- sidebar ----------
    Rectangle {
        id: side
        anchors { left: parent.left; top: parent.top; bottom: mini.top; margins: 10 }
        width: 230; radius: 14; color: "#14ffffff"
        Text { id: sideTitle; x: 16; y: 14; text: "Library"; color: "white"; font.pixelSize: 15; font.bold: true }
        Column {
            visible: !backend.signedIn
            anchors { left: parent.left; right: parent.right; top: sideTitle.bottom; margins: 16 }
            spacing: 12
            Text { width: parent.width; wrapMode: Text.WordWrap; color: "#b3ffffff"; font.pixelSize: 12
                   text: "Sign in to see your playlists and liked songs." }
            Pill { text: "Sign in"; primary: true; onClicked: root.signInRequested() }
        }
        ListView {
            visible: backend.signedIn
            anchors { left: parent.left; right: parent.right; top: sideTitle.bottom; bottom: parent.bottom; margins: 8; topMargin: 10 }
            clip: true; spacing: 2
            model: backend.playlists
            delegate: Rectangle {
                readonly property bool selected: backend.listInfo.id === modelData.id
                width: ListView.view.width; height: 46; radius: 10
                color: selected ? "#2effffff" : (hov.hovered ? "#1fffffff" : "transparent")
                Behavior on color { ColorAnimation { duration: 120 } }
                HoverHandler { id: hov }
                TapHandler { onTapped: backend.openPlaylist(modelData.id) }
                Row {
                    anchors { fill: parent; margins: 6 }
                    spacing: 10
                    Rectangle {
                        width: 34; height: 34; radius: 8; color: "#26ffffff"
                        Image { anchors.fill: parent; source: modelData.thumb; fillMode: Image.PreserveAspectCrop; asynchronous: true; visible: modelData.thumb !== "" }
                        Text { anchors.centerIn: parent; visible: modelData.thumb === ""; text: "♥"; color: root.accent; font.pixelSize: 16 }
                    }
                    Text { anchors.verticalCenter: parent.verticalCenter; width: parent.width - 48; text: modelData.title; color: "white"; font.pixelSize: 13; elide: Text.ElideRight }
                }
            }
        }
    }

    // ---------- playlist content ----------
    Item {
        id: content
        anchors { left: side.right; right: parent.right; top: parent.top; bottom: mini.top; margins: 10 }

        Text {
            anchors.centerIn: parent
            visible: !root.hasList
            text: backend.signedIn ? "Pick a playlist on the left" : "Sign in to see your library"
            color: "#80ffffff"; font.pixelSize: 14
        }
        Item {
            id: header
            visible: root.hasList
            anchors { left: parent.left; right: parent.right; top: parent.top }
            height: 130
            Image { id: cov; width: 110; height: 110; anchors.verticalCenter: parent.verticalCenter
                    source: backend.listInfo.cover || ""; fillMode: Image.PreserveAspectCrop; asynchronous: true }
            TextField {
                anchors { right: parent.right; top: parent.top; topMargin: 8 }
                width: 200
                placeholderText: "Find in playlist"; placeholderTextColor: "#80ffffff"
                color: "white"; font.pixelSize: 12; leftPadding: 14
                text: backend.listFilter
                onTextEdited: backend.setListFilter(text)
                background: Rectangle { radius: 16; color: "#26ffffff"; implicitHeight: 30 }
            }
            Column {
                anchors { left: cov.right; leftMargin: 18; right: parent.right; verticalCenter: parent.verticalCenter }
                spacing: 8
                Rectangle {
                    width: badge.implicitWidth + 18; height: 20; radius: 10; color: "#26ffffff"
                    Text { id: badge; anchors.centerIn: parent; text: "PLAYLIST"; color: root.accent; font.pixelSize: 10; font.bold: true }
                }
                Text { width: parent.width - 220; text: backend.listInfo.title || ""; color: "white"; font.pixelSize: 26; font.bold: true; elide: Text.ElideRight }
                Text { text: root.meta; color: "#b3ffffff"; font.pixelSize: 12 }
                Row {
                    spacing: 8
                    Pill { text: "Play"; primary: true; fill: root.accent; onClicked: backend.playList() }
                    Pill { text: "Shuffle"; onClicked: backend.shuffleList() }
                }
            }
        }
        ListView {
            visible: root.hasList
            anchors { left: parent.left; right: parent.right; top: header.bottom; bottom: parent.bottom }
            clip: true; spacing: 2
            model: backend.listTracks
            delegate: Rectangle {
                readonly property bool nowPlaying: backend.track.videoId === modelData.videoId
                width: ListView.view.width; height: 48; radius: 10
                color: nowPlaying ? "#2effffff" : (hov2.hovered ? "#1fffffff" : "transparent")
                Behavior on color { ColorAnimation { duration: 120 } }
                HoverHandler { id: hov2 }
                TapHandler { onTapped: backend.playListItem(index) }
                Row {
                    anchors { fill: parent; leftMargin: 8; rightMargin: 8; topMargin: 6; bottomMargin: 6 }
                    spacing: 10
                    Text { width: 24; anchors.verticalCenter: parent.verticalCenter; text: index + 1; color: "#80ffffff"; font.pixelSize: 11; horizontalAlignment: Text.AlignRight }
                    Image { width: 36; height: 36; source: modelData.thumb; fillMode: Image.PreserveAspectCrop; asynchronous: true }
                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 24 - 36 - 56 - 30
                        Text { width: parent.width; text: modelData.title; color: parent.parent.parent.nowPlaying ? root.accent : "white"; font.pixelSize: 13; elide: Text.ElideRight }
                        Text { width: parent.width; text: modelData.artist; color: "#99ffffff"; font.pixelSize: 11; elide: Text.ElideRight }
                    }
                    Text { width: 46; anchors.verticalCenter: parent.verticalCenter; text: modelData.duration ? root.fmt(modelData.duration) : ""; color: "#99ffffff"; font.pixelSize: 11; horizontalAlignment: Text.AlignRight }
                }
            }
        }
    }

    // ---------- mini player ----------
    Rectangle {
        id: mini
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: 10 }
        height: 64; radius: 14; color: "#1fffffff"

        Row {
            anchors { left: parent.left; leftMargin: 10; verticalCenter: parent.verticalCenter }
            spacing: 10
            Image { width: 44; height: 44; source: backend.track.thumb || ""; fillMode: Image.PreserveAspectCrop; asynchronous: true }
            Column {
                anchors.verticalCenter: parent.verticalCenter
                width: 190
                Text { width: parent.width; text: backend.track.title || "Nothing playing"; color: "white"; font.pixelSize: 13; font.bold: true; elide: Text.ElideRight }
                Text { width: parent.width; text: backend.track.artist || ""; color: "#99ffffff"; font.pixelSize: 11; elide: Text.ElideRight }
            }
        }
        Row {
            anchors.centerIn: parent
            spacing: 20
            IconButton { width: 22; height: 22; anchors.verticalCenter: parent.verticalCenter; kind: "prev"; onClicked: backend.previous() }
            Rectangle {
                width: 38; height: 38; radius: backend.playing ? 19 : 13; color: "white"
                Behavior on radius { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                Glyph { anchors.centerIn: parent; width: 20; height: 20; kind: backend.playing ? "pause" : "play"; col: "#111111" }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: backend.playPause() }
            }
            IconButton { width: 22; height: 22; anchors.verticalCenter: parent.verticalCenter; kind: "next"; onClicked: backend.next() }
        }
        Row {
            anchors { right: parent.right; rightMargin: 14; verticalCenter: parent.verticalCenter }
            spacing: 8
            Text { anchors.verticalCenter: parent.verticalCenter; text: root.fmt(backend.position / 1000); color: "#99ffffff"; font.pixelSize: 11 }
            WavySlider {
                width: Math.max(80, Math.min(220, root.width * 0.18)); height: 22
                anchors.verticalCenter: parent.verticalCenter
                from: 0; to: Math.max(1, backend.duration); value: backend.position
                accent: root.accent; playing: backend.playing
                onSeekRequested: (v) => backend.seek(v)
            }
        }
    }
}
