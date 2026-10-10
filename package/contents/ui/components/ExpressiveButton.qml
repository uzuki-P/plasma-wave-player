import QtQuick
import org.kde.kirigami as Kirigami

// Material 3 Expressive icon button.
// Corners morph between round and square: pressed buttons and selected
// toggles get squarer corners, with a springy overshoot.
Item {
    id: button

    enum Variant {
        Standard,
        Tonal,
        Filled
    }

    property int variant: ExpressiveButton.Variant.Standard
    property string iconName
    property bool checkable: false
    property bool checked: false
    property real iconScale: 0.5
    property var m3
    property string toolTip: ""
    property real restRadius: Math.min(width, height) / 2
    property real squareRadius: Math.min(width, height) * 0.3

    readonly property alias pressed: mouse.pressed

    signal clicked()

    implicitWidth: Kirigami.Units.gridUnit * 2
    implicitHeight: implicitWidth
    opacity: enabled ? 1 : 0.38

    readonly property bool filled: variant === ExpressiveButton.Variant.Filled || (checkable && checked)
    readonly property color containerColor: {
        if (filled) {
            return m3.primary;
        }
        if (variant === ExpressiveButton.Variant.Tonal) {
            return m3.secondaryContainer;
        }
        return "transparent";
    }
    readonly property color contentColor: {
        if (filled) {
            return m3.primaryContent;
        }
        if (variant === ExpressiveButton.Variant.Tonal) {
            return m3.secondaryContainerContent;
        }
        return m3.surfaceVariantContent;
    }

    Rectangle {
        id: container
        anchors.centerIn: parent
        width: parent.width
        height: parent.height
        color: button.containerColor
        radius: mouse.pressed || (button.checkable && button.checked) ? button.squareRadius : button.restRadius

        Behavior on radius {
            NumberAnimation {
                duration: 350
                easing.type: Easing.OutBack
                easing.overshoot: 2
            }
        }
        Behavior on color {
            ColorAnimation { duration: Kirigami.Units.longDuration }
        }

        Rectangle {
            // State layer.
            anchors.fill: parent
            radius: parent.radius
            color: button.contentColor
            opacity: mouse.pressed ? 0.12 : mouse.containsMouse ? 0.08 : 0
            Behavior on opacity {
                NumberAnimation { duration: Kirigami.Units.shortDuration }
            }
        }
    }

    Kirigami.Icon {
        anchors.centerIn: parent
        width: Math.round(Math.min(button.width, button.height) * button.iconScale)
        height: width
        source: button.iconName
        color: button.contentColor
        isMask: true
        scale: mouse.pressed ? 0.88 : 1
        Behavior on scale {
            NumberAnimation { duration: 250; easing.type: Easing.OutBack; easing.overshoot: 3 }
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: button.clicked()
    }
}
