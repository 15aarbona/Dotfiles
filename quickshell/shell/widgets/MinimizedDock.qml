/* quickshell/shell/widgets/MinimizedDock.qml */

import QtQuick
import Quickshell
import Quickshell.Wayland
import ElysianShell.Services
import ElysianShell.Themes
import "base"

// qmllint disable uncreatable-type
PanelWindow {
// qmllint enable uncreatable-type
    id: root

    readonly property var windows: WorkspaceService.minimizedWindows
    readonly property bool hasMinimized: windows.length > 0
    property bool hovered: false

    // Solo existe si hay al menos 1 app minimizada
    visible: hasMinimized
    color: "transparent"

    anchors {
        bottom: true
        left: true
        right: true
    }

    // Altura fija del área de ventana para evitar redimensionados bruscos de Wayland
    implicitHeight: 84
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    WlrLayershell.namespace: "minimized-dock"

    // Máscara de entrada:
    // - Oculto: solo captura los 4px del borde inferior de la pantalla
    // - Desplegado: captura toda el área de la píldora del dock
    mask: Region {
        item: root.hovered ? dockContainer : edgeTrigger
    }

    // Resuelve el icono buscando el DesktopEntry por appId (class)
    function resolveIcon(appId) {
        if (!appId) return "image://icon/application-x-executable"
        const lower = appId.toLowerCase()
        const entries = DesktopEntries.applications.values
        for (let i = 0; i < entries.length; i++) {
            const entry = entries[i]
            if ((entry.id && entry.id.toLowerCase().includes(lower)) ||
                (entry.name && entry.name.toLowerCase() === lower)) {
                if (entry.icon) return "image://icon/" + entry.icon
            }
        }
        return "image://icon/" + lower
    }

    Timer {
        id: hideTimer
        interval: 250
        onTriggered: root.hovered = false
    }

    // Franja disparadora en el borde inferior (4px)
    Item {
        id: edgeTrigger
        anchors {
            bottom: parent.bottom
            horizontalCenter: parent.horizontalCenter
        }
        width: Math.max(dockContainer.width + 40, 260)
        height: 4

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            onEntered: {
                hideTimer.stop()
                root.hovered = true
            }
        }
    }

    // Contenedor principal del dock
    Item {
        id: dockContainer
        anchors.horizontalCenter: parent.horizontalCenter
        y: root.hovered ? (parent.height - height - 10) : (parent.height + 8)
        width: rowLayout.implicitWidth + 24
        height: 60

        Behavior on y {
            NumberAnimation {
                duration: 220
                easing.type: Easing.OutCubic
            }
        }

        // Fondo oscuro base + tu componente Glass
        Rectangle {
            anchors.fill: parent
            radius: 16
            color: Qt.alpha(ActiveTheme.colors["BG"] ?? "#11111b", 0.85)
        }

        Glass {
            anchors.fill: parent
            radius: 16
            tint: 1.2
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            onEntered: {
                hideTimer.stop()
                root.hovered = true
            }
            onExited: hideTimer.restart()
        }

        Row {
            id: rowLayout
            anchors.centerIn: parent
            spacing: 10

            Repeater {
                model: root.windows

                delegate: Rectangle {
                    required property var modelData
                    width: 44
                    height: 44
                    radius: 11
                    color: itemArea.containsMouse
                           ? Qt.alpha(ActiveTheme.colors["ACCENT"] ?? "#89b4fa", 0.22)
                           : "transparent"

                    Behavior on color {
                        ColorAnimation { duration: 120 }
                    }

                    Image {
                        anchors.centerIn: parent
                        width: 30
                        height: 30
                        source: root.resolveIcon(modelData.appId)
                        sourceSize: Qt.size(30, 30)
                        smooth: true
                    }

                    Tooltip {
                        visible: itemArea.containsMouse
                        text: modelData.title
                    }

                    MouseArea {
                        id: itemArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: {
                            hideTimer.stop()
                            root.hovered = true
                        }
                        onExited: hideTimer.restart()
                        onClicked: {
                            root.hovered = false
                            WorkspaceService.restoreWindow(modelData.address)
                        }
                    }
                }
            }
        }
    }
}
