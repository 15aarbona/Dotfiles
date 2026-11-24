/* quickshell/modules/Services/Workspace/WorkspaceService.qml */

pragma Singleton

import Quickshell
import Quickshell.Hyprland
import ElysianShell.Themes
import QtQuick

Singleton {
    id: root

    readonly property int count: 10
    readonly property int minIndicators: 5

    // Fired only on genuine, user-requested workspace switches
    signal switched()

    // One entry per possible workspace slot — everything ControlPill
    // needs to render, with no Hyprland types leaking out.
    property var states: []

    // Lista reactiva de ventanas en special:minimized
    property var minimizedWindows: []

    function _rebuild() {
        const focusedId = Hyprland.focusedWorkspace?.id ?? 0
        const list = []

        for (let i = 0; i < root.count; i++) {
            const wsId = i + 1
            let hyprWs = null
            for (let j = 0; j < Hyprland.workspaces.values.length; j++) {
                if (Hyprland.workspaces.values[j].id === wsId) {
                    hyprWs = Hyprland.workspaces.values[j]
                    break
                }
            }

            list.push({
                id:      wsId,
                active:  hyprWs?.focused ?? false,
                exists:  hyprWs !== null,
                visible: wsId <= focusedId || i < root.minIndicators
            })
        }

        root.states = list
    }

    function _rebuildMinimized() {
        const list = []
        const toplevels = Hyprland.toplevels?.values ?? []
        for (let i = 0; i < toplevels.length; i++) {
            const win = toplevels[i]
            if (win.workspace?.name === "special:minimized") {
                list.push({
                    address: win.address,
                    title:   win.title || win.appId || "App",
                    appId:   win.appId || ""
                })
            }
        }
        root.minimizedWindows = list
    }

    function restoreWindow(address) {
        const targetWs = Hyprland.focusedWorkspace?.id ?? 1
        Hyprland.dispatch("movetoworkspace " + targetWs + ",address:0x" + address)
        Hyprland.dispatch("focuswindow address:0x" + address)
    }

    // Pure function, called from a QML binding — property reads inside
    // (ActiveTheme.colors[...]) are still tracked, so bindings that call
    // this stay reactive to theme changes even though `states` itself
    // is a plain pre-computed array.
    function colorFor(active, exists) {
        return active ? ActiveTheme.colors["SECONDARY"]
             : exists ? ActiveTheme.colors["WARNING"]
             :          ActiveTheme.colors["FG_HINT"]
    }

    function activate(workspaceId) {
        let hyprWs = null
        for (let j = 0; j < Hyprland.workspaces.values.length; j++) {
            if (Hyprland.workspaces.values[j].id === workspaceId) {
                hyprWs = Hyprland.workspaces.values[j]
                break
            }
        }
        if (hyprWs) hyprWs.activate()
        else Hyprland.dispatch("hl.dsp.focus({ workspace = " + workspaceId + " })")
    }

    Connections {
        target: Hyprland.workspaces
        function onValuesChanged() { root._rebuild() }
    }

    Connections {
        target: Hyprland.toplevels
        function onValuesChanged() { root._rebuildMinimized() }
    }

    Connections {
        target: Hyprland

        function onFocusedWorkspaceChanged() { root._rebuild() }

        function onRawEvent(event) {
            if (event.name === "workspacev2") root.switched()
            if (event.name === "movewindow" || event.name === "movewindowv2" ||
                event.name === "openwindow" || event.name === "closewindow" ||
                event.name === "windowtitle" || event.name === "windowtitlev2") {
                root._rebuildMinimized()
            }
        }
    }

    Component.onCompleted: {
        _rebuild()
        _rebuildMinimized()
    }
}