import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import org.kde.kirigami as Kirigami
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasmoid
import "components"

Item {
    id: compact

    readonly property bool vertical: Plasmoid.formFactor === PlasmaCore.Types.Vertical
    readonly property real thickness: vertical ? width : height
    // Thin panels need every pixel for the text.
    readonly property real inset: thickness <= 28 ? 1 : Math.round(thickness * 0.08)
    readonly property real pillThickness: thickness - inset * 2
    readonly property var player: root.player
    readonly property var m3: root.m3
    readonly property real fontSize: Math.max(11, Math.min(Kirigami.Theme.defaultFont.pixelSize * 1.05, pillThickness * 0.68))

    property real fullLength: player.ready ? root.cfg.panelLength : idleRow.implicitWidth + pillThickness
    Layout.preferredWidth: vertical ? -1 : fullLength
    Layout.minimumWidth: vertical ? -1 : fullLength
    Layout.preferredHeight: vertical ? pillThickness * 2 + inset * 3 : -1
    Layout.fillHeight: !vertical
    Layout.fillWidth: vertical

    Behavior on fullLength {
        NumberAnimation { duration: 450; easing.type: Easing.OutBack; easing.overshoot: 1.2 }
    }

    // A handler, unlike MouseArea.containsMouse, keeps reporting hover over child items.
    HoverHandler {
        id: pointer
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.BackButton | Qt.ForwardButton
        hoverEnabled: true
        onClicked: mouse => {
            if (mouse.button === Qt.MiddleButton) {
                player.playPause();
            } else if (mouse.button === Qt.BackButton) {
                player.previous();
            } else if (mouse.button === Qt.ForwardButton) {
                player.next();
            } else if (mouse.modifiers & Qt.ControlModifier) {
                player.raise();
            } else {
                root.expanded = !root.expanded;
            }
        }
        onWheel: wheel => {
            const step = root.cfg.volumeStep / 100;
            player.changeVolume(wheel.angleDelta.y > 0 ? step : -step);
        }
    }

    Rectangle {
        id: pill
        anchors.fill: parent
        anchors.margins: compact.inset
        radius: Math.min(width, height) / 2
        color: m3.surfaceContainerHigh
        Behavior on color {
            ColorAnimation { duration: Kirigami.Units.longDuration }
        }
    }

    Wave {
        anchors.fill: pill
        visible: !compact.vertical && root.cfg.showVisualizer && player.ready
        radius: pill.radius
        values: root.cava.values
        style: root.cfg.visualizerStyle
        rainbow: root.cfg.waveColors === 1
        color: m3.primary
        progress: player.length > 0 ? player.position / player.length : -1
        playedAlpha: 0.5
        restAlpha: 0.18
        lineAlpha: 0.75
        heightRatio: 0.85
        floor: 2
    }

    RowLayout {
        id: playingRow
        visible: player.ready && !compact.vertical
        anchors.fill: pill
        anchors.leftMargin: 2
        anchors.rightMargin: 2
        spacing: Kirigami.Units.smallSpacing * 1.5

        Item {
            id: artFrame
            Layout.preferredWidth: pill.height - 4
            Layout.preferredHeight: pill.height - 4
            Layout.alignment: Qt.AlignVCenter

            Image {
                id: art
                anchors.fill: parent
                source: player.artUrl
                fillMode: Image.PreserveAspectCrop
                sourceSize: Qt.size(128, 128)
                asynchronous: true
                visible: status === Image.Ready
                onStatusChanged: {
                    if (status === Image.Ready) {
                        colors.update();
                    } else if (status !== Image.Loading) {
                        root.artColor = "transparent";
                    }
                }
                onVisibleChanged: if (status === Image.Ready) colors.update()
                layer.enabled: true
                layer.effect: OpacityMask {
                    maskSource: Rectangle {
                        width: art.width
                        height: art.height
                        // Circle while playing, rounded square while paused.
                        radius: player.playing ? width / 2 : width * 0.28
                        Behavior on radius {
                            NumberAnimation { duration: 400; easing.type: Easing.OutBack; easing.overshoot: 2 }
                        }
                    }
                }
            }

            Rectangle {
                anchors.fill: parent
                visible: art.status !== Image.Ready
                radius: width / 2
                color: m3.primaryContainer
                Kirigami.Icon {
                    anchors.centerIn: parent
                    width: parent.width * 0.6
                    height: width
                    source: player.iconName
                    color: m3.primaryContainerContent
                }
            }

            Kirigami.ImageColors {
                id: colors
                source: art
                onPaletteChanged: root.artColor = art.status === Image.Ready ? colors.dominant : "transparent"
            }
        }

        MarqueeText {
            id: title
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            text: player.artist ? `${player.title}  ·  ${player.artist}` : player.title
            color: m3.surfaceContent
            font.weight: Font.DemiBold
            font.pixelSize: compact.fontSize
            scrolling: root.scrollsText(root.cfg.panelTextScroll, pointer.hovered)
            speed: root.cfg.textScrollSpeed
        }

        ExpressiveButton {
            Layout.preferredWidth: pill.height - 4
            Layout.preferredHeight: pill.height - 4
            Layout.alignment: Qt.AlignVCenter
            m3: compact.m3
            variant: ExpressiveButton.Variant.Filled
            iconName: player.playing ? "media-playback-pause" : "media-playback-start"
            iconScale: 0.55
            // Square while playing, round while paused, like the M3 Expressive FAB.
            restRadius: player.playing ? height * 0.3 : height / 2
            squareRadius: height * 0.22
            onClicked: player.playPause()
        }
    }

    RowLayout {
        id: idleRow
        visible: !player.ready && !compact.vertical
        anchors.centerIn: pill
        spacing: Kirigami.Units.smallSpacing
        Kirigami.Icon {
            Layout.preferredWidth: pill.height * 0.6
            Layout.preferredHeight: pill.height * 0.6
            source: "view-media-track"
            color: m3.surfaceVariantContent
        }
        Text {
            text: i18n("Nothing playing")
            color: m3.surfaceVariantContent
            font.pixelSize: compact.fontSize
        }
    }

    ColumnLayout {
        visible: compact.vertical
        anchors.fill: pill
        anchors.margins: 2
        spacing: 2
        Kirigami.Icon {
            Layout.fillWidth: true
            Layout.fillHeight: true
            source: player.ready ? player.iconName : "view-media-track"
            color: m3.surfaceVariantContent
        }
        ExpressiveButton {
            Layout.fillWidth: true
            Layout.fillHeight: true
            m3: compact.m3
            variant: ExpressiveButton.Variant.Filled
            enabled: player.ready
            iconName: player.playing ? "media-playback-pause" : "media-playback-start"
            onClicked: player.playPause()
        }
    }
}
