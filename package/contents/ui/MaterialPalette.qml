import QtQuick

// Approximates Material 3 color roles from one seed color.
// It works in HSL instead of HCT, which is close enough for a panel widget.
// The M3 "on" roles are named *Content because QML reads onX as a signal handler.
QtObject {
    id: palette

    property color seed: "#6750A4"
    property bool dark: false

    readonly property real hue: seed.hslHue < 0 ? 0.72 : seed.hslHue
    readonly property real chroma: Math.max(0.35, Math.min(0.8, seed.hslSaturation))

    function tone(saturation, lightness) {
        return Qt.hsla(hue, saturation, lightness, 1);
    }

    readonly property color primary: dark ? tone(chroma, 0.78) : tone(chroma, 0.40)
    readonly property color primaryContent: dark ? tone(chroma, 0.16) : "#ffffff"
    readonly property color primaryContainer: dark ? tone(chroma * 0.7, 0.30) : tone(chroma * 0.9, 0.88)
    readonly property color primaryContainerContent: dark ? tone(chroma, 0.90) : tone(chroma, 0.16)
    readonly property color secondaryContainer: dark ? tone(0.22, 0.27) : tone(0.32, 0.88)
    readonly property color secondaryContainerContent: dark ? tone(0.25, 0.90) : tone(0.3, 0.16)
    readonly property color surface: dark ? tone(0.12, 0.08) : tone(0.3, 0.98)
    readonly property color surfaceContainer: dark ? tone(0.12, 0.12) : tone(0.22, 0.94)
    readonly property color surfaceContainerHigh: dark ? tone(0.12, 0.16) : tone(0.2, 0.915)
    readonly property color surfaceContainerHighest: dark ? tone(0.12, 0.21) : tone(0.18, 0.885)
    readonly property color surfaceContent: dark ? tone(0.1, 0.90) : tone(0.12, 0.11)
    readonly property color surfaceVariantContent: dark ? tone(0.08, 0.78) : tone(0.1, 0.32)
    readonly property color outlineVariant: dark ? tone(0.08, 0.30) : tone(0.12, 0.80)
}
