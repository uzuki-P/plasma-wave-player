import QtQuick

// Single-line text that scrolls back and forth when it doesn't fit.
// With `scrolling` false it elides instead.
Item {
    id: marquee

    property alias text: label.text
    property alias color: label.color
    property alias font: label.font
    property bool scrolling: true
    // Pixels per second.
    property real speed: 40

    readonly property bool overflowing: label.implicitWidth > width
    readonly property alias hovered: hover.hovered

    implicitHeight: label.implicitHeight
    clip: true

    Text {
        id: label
        anchors.verticalCenter: parent.verticalCenter
        width: marquee.scrolling && marquee.overflowing ? implicitWidth : marquee.width
        elide: marquee.scrolling ? Text.ElideNone : Text.ElideRight
        textFormat: Text.PlainText
        maximumLineCount: 1

        SequentialAnimation on x {
            running: marquee.scrolling && marquee.overflowing
            loops: Animation.Infinite
            onRunningChanged: {
                if (running) {
                    settle.stop();
                } else {
                    settle.start();
                }
            }
            PauseAnimation { duration: 600 }
            NumberAnimation {
                from: 0
                to: marquee.width - label.implicitWidth
                duration: Math.max(1000, (label.implicitWidth - marquee.width) / Math.max(1, marquee.speed) * 1000)
                easing.type: Easing.InOutSine
            }
            PauseAnimation { duration: 900 }
            NumberAnimation {
                to: 0
                duration: 500
                easing.type: Easing.OutCubic
            }
        }
    }

    // Slides the text home when scrolling stops partway.
    NumberAnimation {
        id: settle
        target: label
        property: "x"
        to: 0
        duration: 300
        easing.type: Easing.OutCubic
    }

    HoverHandler {
        id: hover
    }
}
