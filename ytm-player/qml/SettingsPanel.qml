import QtQuick
import QtQuick.Controls.Basic

Item {
    id: root
    property bool open: false
    property var prefs
    property int tab: 0
        property color liveAccent: prefs.tintEnabled ? backend.tint : prefs.accent
    signal closeRequested()
    visible: opacity > 0
    opacity: open ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: 200 } }

    Rectangle {
        anchors.fill: parent
        color: "#59000000"
        MouseArea { anchors.fill: parent; onClicked: root.closeRequested() }
    }

    Rectangle {
        id: panel
        readonly property var tabs: ["Account", "Visualizer", "Background", "Playback", "Appearance", "About"]
        width: Math.min(700, root.width - 40)
        height: Math.min(460, root.height - 40)
        anchors.centerIn: parent
        radius: 20
        color: "#bd0b0f14"
        border.color: "#26ffffff"
        scale: root.open ? 1 : 0.94
        Behavior on scale { NumberAnimation { duration: 220; easing.type: Easing.OutBack } }
        MouseArea { anchors.fill: parent }

        Rectangle {
            id: side
            x: 8; y: 8; width: 112; height: parent.height - 16; radius: 14
            color: "#1affffff"
            Row {
                x: 12; y: 12; spacing: 6
                Rectangle { width: 11; height: 11; radius: 6; color: "#ff5f57"
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.closeRequested() } }
                Rectangle { width: 11; height: 11; radius: 6; color: "#febc2e" }
                Rectangle { width: 11; height: 11; radius: 6; color: "#28c840" }
            }
            Column {
                anchors { top: parent.top; topMargin: 40; horizontalCenter: parent.horizontalCenter }
                spacing: 4
                Repeater {
                    model: panel.tabs
                    delegate: Rectangle {
                        width: 96; height: 34; radius: 8
                        color: root.tab === index ? "#38ffffff" : "transparent"
                        Behavior on color { ColorAnimation { duration: 140 } }
                        Text { anchors.centerIn: parent; text: modelData; color: "white"; font.pixelSize: 12 }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.tab = index }
                    }
                }
            }
        }

        Item {
            anchors { left: side.right; right: parent.right; top: parent.top; bottom: parent.bottom; margins: 24 }

            // ---- Account ----
            Column {
                visible: root.tab === 0
                width: parent.width; spacing: 14
                Text { text: "Account"; color: "white"; font.pixelSize: 16; font.bold: true }
                Text {
                    text: backend.signedIn ? ("Signed in" + (backend.accountName ? " as " + backend.accountName : "")) : "Not signed in"
                    color: backend.signedIn ? "#9be8b0" : "#e6ffffff"; font.pixelSize: 13
                }
                Column {
                    visible: !backend.signedIn
                    width: parent.width; spacing: 10
                    Text {
                        width: parent.width; wrapMode: Text.WordWrap; color: "#99ffffff"; font.pixelSize: 11
                        text: "Pick the browser you already use for YouTube Music. The app reads that login once and keeps it on this computer only."
                    }
                    Flow {
                        width: parent.width; spacing: 6
                        Repeater {
                            model: ["firefox", "chrome", "chromium", "brave", "vivaldi", "edge"]
                            delegate: Pill {
                                text: modelData.charAt(0).toUpperCase() + modelData.slice(1)
                                onClicked: backend.signInFromBrowser(modelData)
                            }
                        }
                    }
                    Text { text: "Or paste a Cookie header from music.youtube.com:"; color: "#99ffffff"; font.pixelSize: 11 }
                    Row {
                        spacing: 6
                        width: parent.width
                        TextField {
                            id: ck
                            width: parent.width - useBtn.width - 6
                            placeholderText: "Cookie: …"; placeholderTextColor: "#66ffffff"
                            color: "white"; font.pixelSize: 12; leftPadding: 12
                            background: Rectangle { radius: 14; color: "#26ffffff"; implicitHeight: 28 }
                        }
                        Pill { id: useBtn; text: "Use"; onClicked: { backend.signInWithCookie(ck.text); ck.text = "" } }
                    }
                }
                Row {
                    visible: backend.signedIn
                    spacing: 8
                    Pill { text: "Reload library"; onClicked: backend.loadLibrary() }
                    Pill { text: "Sign out"; onClicked: backend.signOut() }
                }
                Text {
                    visible: backend.notice !== ""
                    width: parent.width; wrapMode: Text.WordWrap
                    text: backend.notice; color: "#b3ffffff"; font.pixelSize: 11
                }
            }

            // ---- Visualizer ----
            Column {
                visible: root.tab === 1
                width: parent.width; spacing: 18
                Text { text: "Visualizer"; color: "white"; font.pixelSize: 16; font.bold: true }
                Item {
                    width: parent.width; height: 30
                    Text { anchors.verticalCenter: parent.verticalCenter; text: "Show audio visualizers"; color: "#e6ffffff"; font.pixelSize: 13 }
                    Toggle { anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                        checked: prefs.vizEnabled; accent: root.liveAccent; onToggled: (v) => prefs.vizEnabled = v }
                }
                Item {
                    width: parent.width; height: 30
                    Text { anchors.verticalCenter: parent.verticalCenter; text: "Style"; color: "#e6ffffff"; font.pixelSize: 13 }
                    Segmented { anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                        options: [{label: "Normal", value: "normal"}, {label: "Circular", value: "circular"}]
                        current: prefs.vizStyle; onPicked: (v) => prefs.vizStyle = v }
                }
                Item {
                    width: parent.width; height: 30
                    Text { anchors.verticalCenter: parent.verticalCenter; text: "Shape"; color: "#e6ffffff"; font.pixelSize: 13 }
                    Segmented { anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                        options: [{label: "Bars", value: "bars"}, {label: "Wave", value: "wave"}]
                        current: prefs.vizShape; onPicked: (v) => prefs.vizShape = v }
                }
                Column {
                    width: parent.width; spacing: 6
                    Item {
                        width: parent.width; height: 18
                        Text { text: "Sensitivity"; color: "#e6ffffff"; font.pixelSize: 13 }
                        Text { anchors.right: parent.right; text: Math.round(prefs.sensitivity * 100) + "%"; color: "#99ffffff"; font.pixelSize: 11 }
                    }
                    FlatSlider { width: parent.width; from: 0.5; to: 2.0; value: prefs.sensitivity
                        accent: root.liveAccent; onMoved: prefs.sensitivity = value }
                }
                Text {
                    width: parent.width; wrapMode: Text.WordWrap; color: "#80ffffff"; font.pixelSize: 11
                    text: "Decoration only. The bars are computed from the audio about thirty times a second while a song plays, which costs some CPU and battery."
                }
            }

            // ---- Background ----
            Column {
                visible: root.tab === 2
                width: parent.width; spacing: 18
                Text { text: "Background"; color: "white"; font.pixelSize: 16; font.bold: true }
                Item {
                    width: parent.width; height: 30
                    Text { anchors.verticalCenter: parent.verticalCenter; text: "Live background"; color: "#e6ffffff"; font.pixelSize: 13 }
                    Toggle { anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                        checked: prefs.liveBg; accent: root.liveAccent; onToggled: (v) => prefs.liveBg = v }
                }
                Column {
                    width: parent.width; spacing: 6
                    Item {
                        width: parent.width; height: 18
                        Text { text: "Reactivity"; color: "#e6ffffff"; font.pixelSize: 13 }
                        Text { anchors.right: parent.right; text: Math.round(prefs.reactivity * 100) + "%"; color: "#99ffffff"; font.pixelSize: 11 }
                    }
                    FlatSlider { width: parent.width; from: 0; to: 1; value: prefs.reactivity; accent: root.liveAccent; onMoved: prefs.reactivity = value }
                }
                Column {
                    width: parent.width; spacing: 6
                    Text { text: "Blur"; color: "#e6ffffff"; font.pixelSize: 13 }
                    FlatSlider { width: parent.width; from: 0; to: 1; value: prefs.bgBlur; accent: root.liveAccent; onMoved: prefs.bgBlur = value }
                }
                Column {
                    width: parent.width; spacing: 6
                    Text { text: "Darkness"; color: "#e6ffffff"; font.pixelSize: 13 }
                    FlatSlider { width: parent.width; from: 0; to: 0.9; value: prefs.bgDim; accent: root.liveAccent; onMoved: prefs.bgDim = value }
                }
            }

            // ---- Playback ----
            Column {
                visible: root.tab === 3
                width: parent.width; spacing: 18
                Text { text: "Playback"; color: "white"; font.pixelSize: 16; font.bold: true }
                Item {
                    width: parent.width; height: 30
                    Text { anchors.verticalCenter: parent.verticalCenter; text: "Autoplay similar songs"; color: "#e6ffffff"; font.pixelSize: 13 }
                    Toggle { anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                        checked: prefs.autoplay; accent: root.liveAccent; onToggled: (v) => prefs.autoplay = v }
                }
                Text {
                    width: parent.width; wrapMode: Text.WordWrap; color: "#80ffffff"; font.pixelSize: 11
                    text: "When the queue runs low, the app adds songs similar to the one playing, like YouTube Music's radio. Turn it off to stop at the end of your list."
                }
            }

            // ---- Appearance ----
            Column {
                visible: root.tab === 4
                width: parent.width; spacing: 18
                Text { text: "Appearance"; color: "white"; font.pixelSize: 16; font.bold: true }
                Item {
                    width: parent.width; height: 30
                    Text { anchors.verticalCenter: parent.verticalCenter; text: "Tint from album art"; color: "#e6ffffff"; font.pixelSize: 13 }
                    Toggle { anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                        checked: prefs.tintEnabled; accent: root.liveAccent; onToggled: (v) => prefs.tintEnabled = v }
                }
                Text {
                    width: parent.width; wrapMode: Text.WordWrap; color: "#80ffffff"; font.pixelSize: 11
                    text: "Colors the visualizer, progress bar and highlights from the current cover."
                }
                Item {
                    width: parent.width; height: 30
                    Text { anchors.verticalCenter: parent.verticalCenter; text: "Accent color (when tint is off)"; color: "#e6ffffff"; font.pixelSize: 13 }
                    Row {
                        anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                        spacing: 8
                        Repeater {
                            model: ["#1ed760", "#ff4e45", "#4aa8ff", "#b07cff", "#ffffff"]
                            delegate: Rectangle {
                                width: 22; height: 22; radius: 11; color: modelData
                                border.width: prefs.accent === modelData ? 2 : 0
                                border.color: "#80ffffff"
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: prefs.accent = modelData }
                            }
                        }
                    }
                }
            }

            // ---- About ----
            Column {
                visible: root.tab === 5
                width: parent.width; spacing: 14
                Text { text: "About"; color: "white"; font.pixelSize: 16; font.bold: true }
                Text { width: parent.width; wrapMode: Text.WordWrap; color: "#e6ffffff"; font.pixelSize: 13
                       text: "YTM Player is an unofficial YouTube Music client. It isn't made by or connected to Google." }
                Text { text: "yt-dlp version: " + backend.ytdlpVersion; color: "#b3ffffff"; font.pixelSize: 12 }
                Text { text: "JavaScript runtime: " + backend.jsRuntime; color: "#b3ffffff"; font.pixelSize: 12 }
                Row {
                    spacing: 8
                    Pill { text: "Update yt-dlp"; onClicked: backend.updateYtdlp() }
                    Pill { text: "Install JavaScript runtime"; onClicked: backend.installJsRuntime() }
                }
                Text {
                    width: parent.width; wrapMode: Text.WordWrap; color: "#80ffffff"; font.pixelSize: 11
                    text: "Songs need yt-dlp plus a JavaScript runtime to load. If they stop loading, update yt-dlp (then restart the app) or install the runtime."
                }
                Text {
                    visible: backend.notice !== ""
                    width: parent.width; wrapMode: Text.WordWrap
                    text: backend.notice; color: "#b3ffffff"; font.pixelSize: 11
                }
            }
        }
    }
}
