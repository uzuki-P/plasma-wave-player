import QtQuick
import org.kde.kirigami as Kirigami
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasmoid

PlasmoidItem {
    id: root

    readonly property var cfg: Plasmoid.configuration
    property alias player: player
    property alias cava: cava
    property alias m3: m3

    // Set by CompactView, which owns the always-rendered album art image.
    property color artColor: "transparent"
    readonly property color seedColor: {
        if (cfg.paletteSource === 0 && artColor.a > 0 && artColor.hslSaturation > 0.12) {
            return artColor;
        }
        return Kirigami.Theme.highlightColor;
    }

    // mode 0: always, 1: on hover, 2: never
    function scrollsText(mode, hovered) {
        return mode === 0 || (mode === 1 && hovered);
    }

    function formatTime(microseconds) {
        const total = Math.max(0, Math.floor(microseconds / 1e6));
        const h = Math.floor(total / 3600);
        const m = Math.floor(total / 60) % 60;
        const s = String(total % 60).padStart(2, "0");
        return h > 0 ? `${h}:${String(m).padStart(2, "0")}:${s}` : `${m}:${s}`;
    }

    PlayerSource {
        id: player
        preferredIdentity: root.cfg.lastPlayer
        onPreferredIdentityChanged: root.cfg.lastPlayer = preferredIdentity
    }

    CavaSource {
        id: cava
        active: root.cfg.showVisualizer && player.playing
        bars: root.cfg.barCount
        framerate: root.cfg.framerate
    }

    MaterialPalette {
        id: m3
        seed: root.seedColor
        dark: Kirigami.ColorUtils.brightnessForColor(Kirigami.Theme.backgroundColor) === Kirigami.ColorUtils.Dark
    }

    Plasmoid.icon: "uzuki-waveplayer"
    preferredRepresentation: compactRepresentation
    compactRepresentation: CompactView {}
    fullRepresentation: FullView {}

    toolTipTextFormat: Text.PlainText
    toolTipMainText: player.ready ? player.title : i18n("Nothing playing")
    toolTipSubText: {
        if (!player.ready) {
            return cava.error ? i18n("Visualizer: %1", cava.error) : "";
        }
        const lines = [player.artist ? i18n("%1 · %2", player.artist, player.identity) : player.identity];
        lines.push(i18n("Middle-click to play or pause, scroll for volume"));
        if (cava.error) {
            lines.push(i18n("Visualizer: %1", cava.error));
        }
        return lines.join("\n");
    }

    Plasmoid.contextualActions: [
        PlasmaCore.Action {
            text: i18n("Bring player to front")
            icon.name: "window"
            enabled: player.canRaise
            onTriggered: player.raise()
        },
        PlasmaCore.Action {
            text: root.cfg.showVisualizer ? i18n("Hide visualizer") : i18n("Show visualizer")
            icon.name: "waveform-symbolic"
            onTriggered: root.cfg.showVisualizer = !root.cfg.showVisualizer
        }
    ]
}
