import QtQuick
import QtQuick.Controls as QQC2
import org.kde.kcmutils as KCM
import org.kde.kirigami as Kirigami

KCM.SimpleKCM {
    property alias cfg_paletteSource: paletteSource.currentIndex
    property alias cfg_waveColors: waveColors.currentIndex
    property alias cfg_visualizerStyle: visualizerStyle.currentIndex
    property alias cfg_showVisualizer: showVisualizer.checked
    property alias cfg_barCount: barCount.value
    property alias cfg_framerate: framerate.value
    property alias cfg_panelLength: panelLength.value
    property alias cfg_volumeStep: volumeStep.value
    property alias cfg_panelTextScroll: panelTextScroll.currentIndex
    property alias cfg_popupTextScroll: popupTextScroll.currentIndex
    property alias cfg_textScrollSpeed: textScrollSpeed.value
    property var cfg_paletteSourceDefault
    property var cfg_waveColorsDefault
    property var cfg_visualizerStyleDefault
    property var cfg_showVisualizerDefault
    property var cfg_barCountDefault
    property var cfg_framerateDefault
    property var cfg_panelLengthDefault
    property var cfg_volumeStepDefault
    property var cfg_panelTextScrollDefault
    property var cfg_popupTextScrollDefault
    property var cfg_textScrollSpeedDefault
    property var cfg_lastPlayer
    property var cfg_lastPlayerDefault

    Kirigami.FormLayout {
        QQC2.ComboBox {
            id: paletteSource
            Kirigami.FormData.label: i18n("Colors from:")
            model: [i18n("Album art"), i18n("System accent")]
        }
        QQC2.SpinBox {
            id: panelLength
            Kirigami.FormData.label: i18n("Panel width:")
            from: 120
            to: 1200
            stepSize: 10
            textFromValue: value => i18n("%1 px", value)
            valueFromText: text => parseInt(text, 10)
        }
        QQC2.SpinBox {
            id: volumeStep
            Kirigami.FormData.label: i18n("Scroll volume step:")
            from: 1
            to: 25
            textFromValue: value => i18n("%1%", value)
            valueFromText: text => parseInt(text, 10)
        }

        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18n("Long titles")
        }
        QQC2.ComboBox {
            id: panelTextScroll
            Kirigami.FormData.label: i18n("Scroll in panel:")
            model: [i18n("Always"), i18n("On hover"), i18n("Never")]
        }
        QQC2.ComboBox {
            id: popupTextScroll
            Kirigami.FormData.label: i18n("Scroll in popup:")
            model: [i18n("Always"), i18n("On hover"), i18n("Never")]
        }
        QQC2.SpinBox {
            id: textScrollSpeed
            Kirigami.FormData.label: i18n("Scroll speed:")
            enabled: panelTextScroll.currentIndex !== 2 || popupTextScroll.currentIndex !== 2
            from: 10
            to: 200
            stepSize: 10
            textFromValue: value => i18n("%1 px/s", value)
            valueFromText: text => parseInt(text, 10)
        }

        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18n("Visualizer")
        }
        QQC2.CheckBox {
            id: showVisualizer
            Kirigami.FormData.label: i18n("Visualizer:")
            text: i18n("Show while playing")
        }
        QQC2.ComboBox {
            id: visualizerStyle
            Kirigami.FormData.label: i18n("Style:")
            enabled: showVisualizer.checked
            model: [i18n("Wave"), i18n("Bars")]
        }
        QQC2.ComboBox {
            id: waveColors
            Kirigami.FormData.label: i18n("Colors:")
            enabled: showVisualizer.checked
            model: [i18n("Palette"), i18n("Rainbow")]
        }
        QQC2.SpinBox {
            id: barCount
            Kirigami.FormData.label: i18n("Bars:")
            enabled: showVisualizer.checked
            from: 8
            to: 128
            stepSize: 4
        }
        QQC2.SpinBox {
            id: framerate
            Kirigami.FormData.label: i18n("Frame rate:")
            enabled: showVisualizer.checked
            from: 15
            to: 144
            stepSize: 5
            textFromValue: value => i18n("%1 fps", value)
            valueFromText: text => parseInt(text, 10)
        }
    }
}
