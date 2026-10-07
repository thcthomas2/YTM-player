import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import QtQuick.Effects
import QtCore

ApplicationWindow {
    id: win
    width: 1100; height: 680
    minimumWidth: 780; minimumHeight: 520
    visible: true
    color: "transparent"
    flags: Qt.Window | Qt.FramelessWindowHint
    title: hasTrack ? backend.track.title + " · " + backend.track.artist : "YTM Player"

    readonly property bool lyricsOpen: cfg.lyricsOpen
    property bool searchOpen: false
    property bool settingsOpen: false
    property bool libraryOpen: false
    property bool queueOpen: false
    readonly property bool hasTrack: !!backend.track.videoId
    readonly property real bass: {
        var s = backend.spectrum
        if (!s || s.length < 4) return 0
        return Math.min(1, (s[0] + s[1] + s[2] + s[3]) / 4 * cfg.sensitivity)
    }
    // colours follow the album art when tint is on
    property color vizColor: cfg.tintEnabled ? backend.tint : "#ffffff"
    property color uiAccent: cfg.tintEnabled ? backend.tint : cfg.accent
    Behavior on vizColor { ColorAnimation { duration: 700 } }
    Behavior on uiAccent { ColorAnimation { duration: 700 } }

    function fmt(ms) { var s = Math.floor(ms / 1000); return Math.floor(s / 60) + ":" + ("0" + (s % 60)).slice(-2) }

    Settings {
        id: cfg
        category: "ui2"
        property bool lyricsOpen: false
        property bool vizEnabled: true
        property string vizStyle: "circular"
        property string vizShape: "bars"
        property real sensitivity: 1.2
        property real bgBlur: 1.0
        property real bgDim: 0.28
        property string accent: "#1ed760"
        property bool autoplay: true
        property bool tintEnabled: true
        property bool liveBg: true
        property real reactivity: 0.3
    }
    Connections {
        target: cfg
        function onVizEnabledChanged() { backend.setVisualizerEnabled(cfg.vizEnabled) }
        function onAutoplayChanged() { backend.setAutoplay(cfg.autoplay) }
    }
    Component.onCompleted: {
        backend.setVisualizerEnabled(cfg.vizEnabled)
        backend.setAutoplay(cfg.autoplay)
    }
    Shortcut {
        sequence: "Escape"
        onActivated: { win.searchOpen = false; win.settingsOpen = false; win.queueOpen = false; win.libraryOpen = false }
    }
    Shortcut { sequence: "Ctrl+F"; onActivated: win.searchOpen = true }

    // ---------- blurred album-art background ----------
    Item {
        anchors.fill: parent
        Rectangle { anchors.fill: parent; color: "#0b0f14"; opacity: 0.96 }
        Image {
            id: bgImg
            anchors.fill: parent
            source: backend.track.cover || ""
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            visible: false
            onStatusChanged: if (status === Image.Ready) bgFade.restart()
        }
        MultiEffect {
            id: bgFx
            anchors.fill: parent
            source: bgImg
            blurEnabled: true
            blurMax: 64
            blur: cfg.bgBlur
            saturation: 0.7
            opacity: 0
        }
        NumberAnimation { id: bgFade; target: bgFx; property: "opacity"; from: 0; to: 1; duration: 800; easing.type: Easing.OutCubic }
        LiveBackground {
            anchors.fill: parent
            visible: cfg.liveBg
            opacity: 0.85
            tint: win.uiAccent
            reactivity: cfg.reactivity
            bass: win.bass
            playing: backend.playing
        }
        Rectangle { anchors.fill: parent; color: "black"; opacity: cfg.bgDim }
        // soft shade toward the bottom keeps the controls readable on a bright backdrop
        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop { position: 0.0; color: "#00000000" }
                GradientStop { position: 1.0; color: "#73000000" }
            }
        }
    }

    // ---------- bottom visualizer (Normal style) ----------
    Visualizer {
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        height: 150
        opacity: cfg.vizEnabled && cfg.vizStyle === "normal" ? 1 : 0
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: 250 } }
        style: "normal"; shape: cfg.vizShape; spectrum: backend.spectrum
        sensitivity: cfg.sensitivity; accent: win.vizColor
    }

    // ---------- now playing ----------
    RowLayout {
        anchors { fill: parent; margins: 28; topMargin: 64 }
        spacing: 24
        opacity: win.libraryOpen ? 0 : 1
        Behavior on opacity { NumberAnimation { duration: 220 } }

        Item {
            id: playerPane
            Layout.fillWidth: true
            Layout.fillHeight: true

            ColumnLayout {
                anchors.centerIn: parent
                width: Math.min(parent.width, 440)
                spacing: 14

                Item {
                    id: artHolder
                    readonly property real size: Math.max(160, Math.min(playerPane.width * 0.7, playerPane.height * 0.46))
                    Layout.alignment: Qt.AlignHCenter
                    Layout.preferredWidth: size
                    Layout.preferredHeight: size
                    Layout.bottomMargin: Math.round(size * 0.3)

                    Visualizer {
                        anchors.centerIn: parent
                        width: parent.width * 1.7; height: width
                        opacity: cfg.vizEnabled && cfg.vizStyle === "circular" ? 1 : 0
                        visible: opacity > 0
                        Behavior on opacity { NumberAnimation { duration: 250 } }
                        style: "circular"; shape: cfg.vizShape; spectrum: backend.spectrum
                        sensitivity: cfg.sensitivity; accent: win.vizColor
                    }

                    Item {
                        id: artSpin
                        anchors.fill: parent
                        scale: backend.playing ? 1.0 + win.bass * 0.05 : 0.94
                        Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutQuad } }
                        Image {
                            id: artImg
                            anchors.fill: parent
                            source: backend.track.cover || ""
                            sourceSize: Qt.size(600, 600)
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            visible: false
                        }
                        Rectangle {
                            id: artMask; anchors.fill: parent; layer.enabled: true; visible: false
                            radius: (cfg.vizEnabled && cfg.vizStyle === "circular") ? width / 2 : 16
                            Behavior on radius { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
                        }
                        MultiEffect { anchors.fill: parent; source: artImg; maskEnabled: true; maskSource: artMask }
                        Rectangle { anchors.fill: parent; radius: artMask.radius; color: "transparent"; border.width: 2; border.color: "#33ffffff" }
                    }
                }

                Text {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    text: win.hasTrack ? backend.track.title : "Nothing playing"
                    color: "white"; font.pixelSize: 20; font.bold: true; elide: Text.ElideRight
                }
                Text {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    text: win.hasTrack ? backend.track.artist : "Search for a song to start"
                    color: "#b3ffffff"; font.pixelSize: 13; elide: Text.ElideRight
                }
                Text {
                    Layout.fillWidth: true
                    visible: !!backend.track.album
                    horizontalAlignment: Text.AlignHCenter
                    text: backend.track.album || ""
                    color: "#66ffffff"; font.pixelSize: 11; elide: Text.ElideRight
                }
                Text {
                    Layout.fillWidth: true
                    visible: backend.status !== ""
                    text: backend.status
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.Wrap
                    maximumLineCount: 5
                    elide: Text.ElideRight
                    color: (backend.status === "Loading…" || backend.status === "Retrying…" || backend.status.indexOf("Finding") === 0) ? "#99ffffff" : "#ff8a80"
                    font.pixelSize: 12
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    Text { text: win.fmt(backend.position); color: "#99ffffff"; font.pixelSize: 11 }
                    WavySlider {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 24
                        from: 0; to: Math.max(1, backend.duration); value: backend.position
                        accent: win.uiAccent
                        playing: backend.playing
                        onSeekRequested: (v) => backend.seek(v)
                    }
                    Text { text: win.fmt(backend.duration); color: "#99ffffff"; font.pixelSize: 11 }
                }

                RowLayout {
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 26
                    IconButton { width: 22; height: 22; kind: "shuffle"; col: backend.shuffle ? win.uiAccent : "#b3ffffff"; onClicked: backend.toggleShuffle() }
                    IconButton { width: 26; height: 26; kind: "prev"; onClicked: backend.previous() }
                    Rectangle {
                        width: 54; height: 54; radius: backend.playing ? 27 : 18; color: "white"
                        Behavior on radius { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                        scale: pp.pressed ? 0.92 : (pp.containsMouse ? 1.06 : 1.0)
                        Behavior on scale { NumberAnimation { duration: 110; easing.type: Easing.OutQuad } }
                        Glyph { anchors.centerIn: parent; width: 28; height: 28; kind: backend.playing ? "pause" : "play"; col: "#111" }
                        MouseArea { id: pp; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: backend.playPause() }
                    }
                    IconButton { width: 26; height: 26; kind: "next"; onClicked: backend.next() }
                    IconButton { width: 22; height: 22; kind: "repeat"; col: backend.repeat ? win.uiAccent : "#b3ffffff"; onClicked: backend.toggleRepeat() }
                }

                RowLayout {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.preferredWidth: 200
                    spacing: 8
                    Glyph { width: 16; height: 16; kind: "volume"; col: "#b3ffffff" }
                    FlatSlider {
                        Layout.fillWidth: true
                        from: 0; to: 1; value: backend.volume; accent: "white"
                        onMoved: backend.volume = value
                    }
                }
            }
        }

        // ---------- lyrics ----------
        Item {
            id: lyricsPane
            Layout.fillHeight: true
            Layout.preferredWidth: win.lyricsOpen ? Math.max(300, win.width * 0.4) : 0
            Behavior on Layout.preferredWidth { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }
            opacity: win.lyricsOpen ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 250 } }
            clip: true

            ListView {
                id: lyr
                anchors.fill: parent
                model: backend.lyrics
                currentIndex: backend.lyricIndex
                highlightRangeMode: ListView.StrictlyEnforceRange
                preferredHighlightBegin: height * 0.4
                preferredHighlightEnd: height * 0.6
                highlightMoveDuration: 600
                interactive: false
                delegate: Item {
                    width: lyr.width
                    height: lt.implicitHeight + 28
                    readonly property bool current: index === lyr.currentIndex
                    Rectangle {
                        anchors { fill: parent; topMargin: 3; bottomMargin: 3 }
                        radius: 14; color: "#26ffffff"
                        opacity: (backend.lyricsSynced && parent.current) ? 1 : 0
                        Behavior on opacity { NumberAnimation { duration: 300 } }
                    }
                    Text {
                        id: lt
                        x: 16
                        width: parent.width - 32
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData.text !== "" ? modelData.text : "♪"
                        wrapMode: Text.WordWrap
                        color: "white"; font.pixelSize: 18; font.bold: true
                        opacity: backend.lyricsSynced ? (parent.current ? 1.0 : 0.33) : 0.85
                        scale: parent.current ? 1.04 : 1.0
                        transformOrigin: Item.Left
                        Behavior on opacity { NumberAnimation { duration: 350 } }
                        Behavior on scale { NumberAnimation { duration: 350; easing.type: Easing.OutCubic } }
                    }
                    MouseArea {
                        anchors.fill: parent
                        enabled: backend.lyricsSynced
                        cursorShape: Qt.PointingHandCursor
                        onClicked: backend.seek(modelData.time * 1000)
                    }
                }
            }
            Text {
                anchors.centerIn: parent
                width: parent.width - 40
                horizontalAlignment: Text.AlignHCenter
                visible: win.hasTrack && backend.lyrics.length === 0
                text: backend.status === "Loading…" ? "" : "No lyrics found"
                color: "#80ffffff"; font.pixelSize: 15
            }
        }
    }

    // ---------- library ----------
    LibraryView {
        anchors { fill: parent; topMargin: 60; leftMargin: 20; rightMargin: 20; bottomMargin: 20 }
        z: 8
        open: win.libraryOpen
        accent: win.uiAccent
        onSignInRequested: { settingsPanel.tab = 0; win.settingsOpen = true }
    }

    // ---------- frameless window: drag area, buttons, resize edges ----------
    MouseArea {
        z: 5
        anchors { top: parent.top; left: parent.left; right: parent.right }
        height: 52
        onPressed: win.startSystemMove()
        onDoubleClicked: win.visibility === Window.Maximized ? win.showNormal() : win.showMaximized()
    }
    Row {
        z: 30
        anchors { top: parent.top; left: parent.left; margins: 18 }
        spacing: 8
        Repeater {
            model: [{c: "#ff5f57", a: "close"}, {c: "#febc2e", a: "min"}, {c: "#28c840", a: "max"}]
            delegate: Rectangle {
                width: 13; height: 13; radius: 7; color: modelData.c
                opacity: dma.containsMouse ? 1 : 0.8
                Behavior on opacity { NumberAnimation { duration: 120 } }
                MouseArea {
                    id: dma
                    anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (modelData.a === "close") win.close()
                        else if (modelData.a === "min") win.showMinimized()
                        else if (win.visibility === Window.Maximized) win.showNormal()
                        else win.showMaximized()
                    }
                }
            }
        }
    }
    component Edge: MouseArea {
        property int edges: 0
        z: 100
        onPressed: win.startSystemResize(edges)
    }
    Edge { edges: Qt.LeftEdge; cursorShape: Qt.SizeHorCursor; width: 6; anchors { left: parent.left; top: parent.top; bottom: parent.bottom; topMargin: 8; bottomMargin: 8 } }
    Edge { edges: Qt.RightEdge; cursorShape: Qt.SizeHorCursor; width: 6; anchors { right: parent.right; top: parent.top; bottom: parent.bottom; topMargin: 8; bottomMargin: 8 } }
    Edge { edges: Qt.TopEdge; cursorShape: Qt.SizeVerCursor; height: 6; anchors { top: parent.top; left: parent.left; right: parent.right; leftMargin: 8; rightMargin: 8 } }
    Edge { edges: Qt.BottomEdge; cursorShape: Qt.SizeVerCursor; height: 6; anchors { bottom: parent.bottom; left: parent.left; right: parent.right; leftMargin: 8; rightMargin: 8 } }
    Edge { edges: Qt.TopEdge | Qt.LeftEdge; cursorShape: Qt.SizeFDiagCursor; width: 8; height: 8; anchors { top: parent.top; left: parent.left } }
    Edge { edges: Qt.BottomEdge | Qt.RightEdge; cursorShape: Qt.SizeFDiagCursor; width: 8; height: 8; anchors { bottom: parent.bottom; right: parent.right } }
    Edge { edges: Qt.TopEdge | Qt.RightEdge; cursorShape: Qt.SizeBDiagCursor; width: 8; height: 8; anchors { top: parent.top; right: parent.right } }
    Edge { edges: Qt.BottomEdge | Qt.LeftEdge; cursorShape: Qt.SizeBDiagCursor; width: 8; height: 8; anchors { bottom: parent.bottom; left: parent.left } }

    // ---------- top-right pill ----------
    Rectangle {
        id: pill
        anchors { top: parent.top; right: parent.right; margins: 16 }
        z: 20
        height: 36; width: pillRow.width + 14; radius: 18
        color: "#33ffffff"
        Row {
            id: pillRow
            anchors.centerIn: parent
            spacing: 4
            Repeater {
                model: [
                    {k: "library", g: "library"}, {k: "search", g: "search"}, {k: "queue", g: "queue"},
                    {k: "lyrics", g: "lyrics"}, {k: "viz", g: "viz"}, {k: "settings", g: "gear"}
                ]
                delegate: Rectangle {
                    width: 28; height: 28; radius: 14
                    readonly property bool on: (modelData.k === "library" && win.libraryOpen)
                        || (modelData.k === "search" && win.searchOpen)
                        || (modelData.k === "queue" && win.queueOpen)
                        || (modelData.k === "lyrics" && win.lyricsOpen)
                        || (modelData.k === "viz" && cfg.vizEnabled)
                        || (modelData.k === "settings" && win.settingsOpen)
                    color: on ? "white" : "transparent"
                    Behavior on color { ColorAnimation { duration: 160 } }
                    Glyph { anchors.centerIn: parent; width: 16; height: 16; kind: modelData.g; col: parent.on ? "#111" : "white" }
                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (modelData.k === "library") win.libraryOpen = !win.libraryOpen
                            else if (modelData.k === "search") win.searchOpen = !win.searchOpen
                            else if (modelData.k === "queue") win.queueOpen = !win.queueOpen
                            else if (modelData.k === "lyrics") cfg.lyricsOpen = !cfg.lyricsOpen
                            else if (modelData.k === "viz") cfg.vizEnabled = !cfg.vizEnabled
                            else win.settingsOpen = true
                        }
                    }
                }
            }
        }
    }

    // ---------- search panel (middle-left) ----------
    Rectangle {
        id: searchPanel
        z: 10
        width: 330
        height: Math.min(win.height - 140, 540)
        anchors.verticalCenter: parent.verticalCenter
        x: win.searchOpen ? 20 : -width - 24
        opacity: win.searchOpen ? 1 : 0
        visible: opacity > 0
        Behavior on x { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }
        Behavior on opacity { NumberAnimation { duration: 220 } }
        radius: 20
        color: "#a60b0f14"
        border.color: "#26ffffff"

        ColumnLayout {
            anchors { fill: parent; margins: 14 }
            spacing: 10
            TextField {
                id: q
                Layout.fillWidth: true
                placeholderText: "Search YouTube Music"
                placeholderTextColor: "#80ffffff"
                color: "white"; font.pixelSize: 13; leftPadding: 16
                focus: win.searchOpen
                background: Rectangle { radius: 18; color: "#26ffffff"; implicitHeight: 36 }
                onAccepted: backend.search(text)
            }
            Text {
                visible: backend.status !== ""
                text: backend.status
                color: "#b3ffffff"; font.pixelSize: 11
                Layout.fillWidth: true; wrapMode: Text.WordWrap
            }
            ListView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true; spacing: 2
                model: backend.results
                delegate: Rectangle {
                    readonly property bool nowPlaying: backend.track.videoId === modelData.videoId
                    width: ListView.view.width; height: 54; radius: 12
                    color: nowPlaying ? "#2effffff" : (hov.hovered ? "#1fffffff" : "transparent")
                    Behavior on color { ColorAnimation { duration: 120 } }
                    HoverHandler { id: hov }
                    TapHandler { onTapped: { backend.playResult(index); win.searchOpen = false } }
                    Row {
                        anchors { fill: parent; margins: 7 }
                        spacing: 10
                        Image { width: 40; height: 40; source: modelData.thumb; fillMode: Image.PreserveAspectCrop; asynchronous: true }
                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - 52
                            Text { width: parent.width; text: modelData.title; color: parent.parent.parent.nowPlaying ? win.uiAccent : "white"; font.pixelSize: 13; elide: Text.ElideRight }
                            Text { width: parent.width; text: modelData.artist; color: "#99ffffff"; font.pixelSize: 11; elide: Text.ElideRight }
                        }
                    }
                }
            }
        }
    }

    QueuePanel { open: win.queueOpen; prefs: cfg; accent: win.uiAccent }

    SettingsPanel {
        id: settingsPanel
        anchors.fill: parent
        z: 50
        open: win.settingsOpen
        prefs: cfg
        onCloseRequested: win.settingsOpen = false
    }
}
