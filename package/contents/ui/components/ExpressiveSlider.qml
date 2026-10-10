import QtQuick
import org.kde.kirigami as Kirigami

// Material 3 Expressive slider with an optional wavy active track.
// The handle is a narrow vertical pill with a gap on both sides,
// and the inactive track ends in a stop dot.
Item {
    id: slider

    property real value: 0 // 0..1
    property bool wavy: false
    property bool animating: false
    property bool interactive: true
    property var m3
    property real trackThickness: 4
    property real handleHeight: Kirigami.Units.gridUnit * 1.6

    readonly property bool dragging: mouse.pressed
    readonly property real shownValue: dragging ? dragValue : value
    property real dragValue: 0
    property real phase: 0
    property real amplitude: wavy && animating ? 3 : 0

    signal moved(real value)

    implicitHeight: handleHeight
    implicitWidth: Kirigami.Units.gridUnit * 10

    Behavior on amplitude {
        NumberAnimation { duration: 400; easing.type: Easing.OutCubic }
    }

    onShownValueChanged: track.requestPaint()
    onAmplitudeChanged: track.requestPaint()
    onPhaseChanged: track.requestPaint()

    NumberAnimation on phase {
        from: 0
        to: Math.PI * 2
        duration: 1600
        loops: Animation.Infinite
        running: slider.amplitude > 0 && slider.visible
    }

    Canvas {
        id: track
        anchors.fill: parent
        property color active: slider.m3.primary
        property color inactive: slider.m3.secondaryContainer
        onActiveChanged: requestPaint()
        onInactiveChanged: requestPaint()
        onWidthChanged: requestPaint()

        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            const t = slider.trackThickness;
            const mid = height / 2;
            const handleX = t / 2 + slider.shownValue * (width - t);
            const gap = 6;
            ctx.lineCap = "round";
            ctx.lineWidth = t;

            // Active track.
            const end = handleX - gap;
            if (end > t / 2) {
                ctx.strokeStyle = active;
                ctx.beginPath();
                ctx.moveTo(t / 2, mid);
                const wavelength = 28;
                for (let x = t / 2; x <= end; x += 1) {
                    ctx.lineTo(x, mid + Math.sin(x / wavelength * Math.PI * 2 - slider.phase) * slider.amplitude);
                }
                ctx.stroke();
            }

            // Inactive track and stop dot.
            const start = handleX + gap;
            if (start < width - t / 2) {
                ctx.strokeStyle = inactive;
                ctx.beginPath();
                ctx.moveTo(start, mid);
                ctx.lineTo(width - t / 2, mid);
                ctx.stroke();
                ctx.fillStyle = active;
                ctx.beginPath();
                ctx.arc(width - t / 2, mid, t / 2 * 0.75, 0, Math.PI * 2);
                ctx.fill();
            }
        }
    }

    Rectangle {
        id: handle
        width: slider.dragging ? 2 : 4
        height: slider.handleHeight
        radius: width / 2
        color: slider.m3.primary
        x: slider.trackThickness / 2 + slider.shownValue * (slider.width - slider.trackThickness) - width / 2
        anchors.verticalCenter: parent.verticalCenter
        Behavior on width {
            NumberAnimation { duration: 200; easing.type: Easing.OutBack }
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        enabled: slider.interactive
        cursorShape: Qt.PointingHandCursor
        preventStealing: true
        function valueAt(x) {
            return Math.max(0, Math.min(1, x / width));
        }
        onPressed: event => slider.dragValue = valueAt(event.x)
        onPositionChanged: event => slider.dragValue = valueAt(event.x)
        onReleased: event => slider.moved(valueAt(event.x))
        onWheel: wheel => wheel.accepted = false
    }
}
