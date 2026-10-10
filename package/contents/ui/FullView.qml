import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import org.kde.kirigami as Kirigami
import org.kde.plasma.private.mpris as Mpris
import "components"

Item {
    id: full

    readonly property var player: root.player
    readonly property var m3: root.m3
    readonly property real gu: Kirigami.Units.gridUnit

    Layout.minimumWidth: gu * 20
    Layout.preferredWidth: gu * 20
    Layout.minimumHeight: content.implicitHeight + gu * 1.5
    Layout.preferredHeight: Layout.minimumHeight
    Layout.maximumHeight: Layout.minimumHeight

    // Bar lengths and the shape morph follow M3 Expressive spring timing.
    component Spring: NumberAnimation {
        duration: 420
        easing.type: Easing.OutBack
        easing.overshoot: 1.6
    }

    ColumnLayout {
        id: content
        visible: player.ready
        anchors.fill: parent
        anchors.margins: gu * 0.75
        spacing: gu * 0.75

        // Album art with the visualizer over its lower edge.
        Item {
            id: card
            Layout.fillWidth: true
            Layout.preferredHeight: {
                if (art.status !== Image.Ready || art.implicitWidth <= 0) {
                    return width * 0.6;
                }
                return width * Math.max(0.56, Math.min(1, art.implicitHeight / art.implicitWidth));
            }
            Behavior on Layout.preferredHeight { Spring {} }

            Rectangle {
                id: cardBackground
                anchors.fill: parent
                radius: gu * 1.5
                color: m3.primaryContainer
                Kirigami.Icon {
                    anchors.centerIn: parent
                    visible: art.status !== Image.Ready
                    width: parent.height * 0.35
                    height: width
                    source: player.iconName
                    color: m3.primaryContainerContent
                }
            }

            Item {
                id: cardContent
                anchors.fill: parent
                layer.enabled: true
                layer.effect: OpacityMask {
                    maskSource: Rectangle {
                        width: cardContent.width
                        height: cardContent.height
                        radius: cardBackground.radius
                    }
                }

                Image {
                    id: art
                    anchors.fill: parent
                    source: player.artUrl
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    sourceSize.width: 512
                }

                LinearGradient {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    height: parent.height * 0.5
                    visible: art.status === Image.Ready && root.cfg.showVisualizer
                    start: Qt.point(0, 0)
                    end: Qt.point(0, height)
                    gradient: Gradient {
                        GradientStop { position: 0; color: "transparent" }
                        GradientStop { position: 1; color: Qt.rgba(0, 0, 0, 0.45) }
                    }
                }

                Wave {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    height: parent.height * 0.42
                    visible: root.cfg.showVisualizer
                    values: root.cava.values
                    style: root.cfg.visualizerStyle
                    rainbow: root.cfg.waveColors === 1
                    color: art.status === Image.Ready ? "white" : m3.primary
                    progress: -1
                    playedAlpha: 0.45
                    lineAlpha: 0.95
                    lineWidth: 2
                }
            }

            // Player chip.
            Rectangle {
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.margins: gu * 0.6
                height: gu * 1.6
                width: chipRow.implicitWidth + gu
                radius: height / 2
                color: Qt.alpha(m3.surface, 0.88)
                RowLayout {
                    id: chipRow
                    anchors.centerIn: parent
                    spacing: Kirigami.Units.smallSpacing
                    Kirigami.Icon {
                        Layout.preferredWidth: gu * 0.9
                        Layout.preferredHeight: gu * 0.9
                        source: player.iconName
                    }
                    Text {
                        text: player.identity
                        color: m3.surfaceContent
                        font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                        font.weight: Font.Medium
                    }
                }
                MouseArea {
                    anchors.fill: parent
                    enabled: player.canRaise
                    cursorShape: Qt.PointingHandCursor
                    onClicked: player.raise()
                }
            }
        }

        // Title and artist.
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0
            MarqueeText {
                id: titleText
                Layout.fillWidth: true
                text: player.title
                color: m3.surfaceContent
                font.pixelSize: Math.round(Kirigami.Theme.defaultFont.pixelSize * 1.35)
                font.weight: Font.Bold
                scrolling: root.scrollsText(root.cfg.popupTextScroll, hovered)
                speed: root.cfg.textScrollSpeed
            }
            MarqueeText {
                id: artistText
                Layout.fillWidth: true
                text: player.album && player.album !== player.title ? `${player.artist}  ·  ${player.album}` : player.artist
                color: m3.surfaceVariantContent
                font.pixelSize: Kirigami.Theme.defaultFont.pixelSize
                scrolling: root.scrollsText(root.cfg.popupTextScroll, hovered)
                speed: root.cfg.textScrollSpeed
            }
        }

        // Wavy progress.
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0
            ExpressiveSlider {
                Layout.fillWidth: true
                m3: full.m3
                wavy: true
                animating: player.playing
                interactive: player.canSeek && player.length > 0
                value: player.length > 0 ? player.position / player.length : 0
                onMoved: value => player.seek(value * player.length)
            }
            RowLayout {
                Layout.fillWidth: true
                Text {
                    text: root.formatTime(player.position)
                    color: m3.surfaceVariantContent
                    font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                    font.features: ({ "tnum": 1 })
                }
                Item { Layout.fillWidth: true }
                Text {
                    text: player.length > 0 ? root.formatTime(player.length) : "--:--"
                    color: m3.surfaceVariantContent
                    font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                    font.features: ({ "tnum": 1 })
                }
            }
        }

        // Connected button group. The pressed button grows and its neighbours give way.
        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 4

            ExpressiveButton {
                Layout.preferredWidth: gu * 2.4 + (pressed ? gu * 0.4 : 0)
                Layout.preferredHeight: gu * 2.4
                Behavior on Layout.preferredWidth { Spring {} }
                m3: full.m3
                checkable: true
                checked: player.shuffle === Mpris.ShuffleStatus.On
                enabled: player.canShuffle
                iconName: "media-playlist-shuffle"
                onClicked: player.toggleShuffle()
            }
            ExpressiveButton {
                Layout.preferredWidth: gu * 3.2 + (pressed ? gu * 0.6 : 0)
                Layout.preferredHeight: gu * 3.2
                Behavior on Layout.preferredWidth { Spring {} }
                m3: full.m3
                variant: ExpressiveButton.Variant.Tonal
                enabled: player.canGoPrevious
                iconName: "media-skip-backward"
                iconScale: 0.42
                onClicked: player.previous()
            }
            ExpressiveButton {
                Layout.preferredWidth: gu * (player.playing ? 5.2 : 4.2) + (pressed ? gu * 0.6 : 0)
                Layout.preferredHeight: gu * 3.6
                Behavior on Layout.preferredWidth { Spring {} }
                m3: full.m3
                variant: ExpressiveButton.Variant.Filled
                iconName: player.playing ? "media-playback-pause" : "media-playback-start"
                iconScale: 0.46
                // Pill while paused, rounded square while playing.
                restRadius: player.playing ? height * 0.3 : height / 2
                squareRadius: height * 0.2
                onClicked: player.playPause()
            }
            ExpressiveButton {
                Layout.preferredWidth: gu * 3.2 + (pressed ? gu * 0.6 : 0)
                Layout.preferredHeight: gu * 3.2
                Behavior on Layout.preferredWidth { Spring {} }
                m3: full.m3
                variant: ExpressiveButton.Variant.Tonal
                enabled: player.canGoNext
                iconName: "media-skip-forward"
                iconScale: 0.42
                onClicked: player.next()
            }
            ExpressiveButton {
                Layout.preferredWidth: gu * 2.4 + (pressed ? gu * 0.4 : 0)
                Layout.preferredHeight: gu * 2.4
                Behavior on Layout.preferredWidth { Spring {} }
                m3: full.m3
                checkable: true
                checked: player.loopStatus === Mpris.LoopStatus.Playlist || player.loopStatus === Mpris.LoopStatus.Track
                enabled: player.canLoop
                iconName: player.loopStatus === Mpris.LoopStatus.Track ? "media-repeat-single" : "media-repeat-all"
                onClicked: player.cycleLoop()
            }
        }

        // Volume.
        RowLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing
            ExpressiveButton {
                Layout.preferredWidth: gu * 1.8
                Layout.preferredHeight: gu * 1.8
                m3: full.m3
                iconScale: 0.6
                iconName: player.volume <= 0 ? "audio-volume-muted" : player.volume < 0.34 ? "audio-volume-low" : player.volume < 0.67 ? "audio-volume-medium" : "audio-volume-high"
                property real restore: 0.5
                onClicked: {
                    if (player.volume > 0) {
                        restore = player.volume;
                        player.setVolume(0);
                    } else {
                        player.setVolume(restore);
                    }
                }
            }
            ExpressiveSlider {
                Layout.fillWidth: true
                m3: full.m3
                handleHeight: gu * 1.2
                value: player.volume
                onMoved: value => player.setVolume(value)
            }
            Text {
                Layout.preferredWidth: gu * 2
                horizontalAlignment: Text.AlignRight
                text: `${Math.round(player.volume * 100)}%`
                color: m3.surfaceVariantContent
                font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                font.features: ({ "tnum": 1 })
            }
        }

        // Source picker: every player that has media.
        Flow {
            Layout.fillWidth: true
            visible: player.players.length > 0
            spacing: Kirigami.Units.smallSpacing
            Repeater {
                model: player.players
                delegate: Rectangle {
                    required property var modelData
                    readonly property bool selected: modelData === player.current
                    height: gu * 1.8
                    width: chipLabel.implicitWidth + gu * (selected ? 2.4 : 1.4)
                    radius: selected ? height / 2 : gu * 0.5
                    color: selected ? m3.secondaryContainer : "transparent"
                    border.width: selected ? 0 : 1
                    border.color: m3.outlineVariant
                    Behavior on radius { Spring {} }
                    Behavior on width { Spring {} }
                    RowLayout {
                        anchors.centerIn: parent
                        spacing: Kirigami.Units.smallSpacing
                        Kirigami.Icon {
                            visible: selected
                            Layout.preferredWidth: gu * 0.8
                            Layout.preferredHeight: gu * 0.8
                            source: "checkmark"
                            color: m3.secondaryContainerContent
                            isMask: true
                        }
                        Text {
                            id: chipLabel
                            text: modelData.identity + (modelData.playbackStatus === Mpris.PlaybackStatus.Playing ? "  ▶" : "")
                            color: selected ? m3.secondaryContainerContent : m3.surfaceVariantContent
                            font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                            font.weight: Font.Medium
                        }
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: player.pick(modelData)
                    }
                }
            }
        }
    }

    ColumnLayout {
        visible: !player.ready
        anchors.centerIn: parent
        spacing: Kirigami.Units.largeSpacing
        Kirigami.Icon {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: gu * 3
            Layout.preferredHeight: gu * 3
            source: "view-media-track"
            color: m3.surfaceVariantContent
        }
        Text {
            Layout.alignment: Qt.AlignHCenter
            text: i18n("Nothing playing")
            color: m3.surfaceVariantContent
            font.pixelSize: Math.round(Kirigami.Theme.defaultFont.pixelSize * 1.2)
        }
    }
}
