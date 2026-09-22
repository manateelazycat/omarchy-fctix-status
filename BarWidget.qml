// SPDX-License-Identifier: GPL-3.0-only

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import qs.Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "io.github.manateelazycat.fcitx-status"

  property var status: ({
    ready: false,
    mode: "unknown",
    state: 0,
    inputMethod: "",
    message: "正在读取 Fcitx5 状态…"
  })
  property bool refreshPending: false

  readonly property string controlPath: root.localPath(Qt.resolvedUrl("scripts/fcitx-statusctl"))
  readonly property string label: status.ready === true
    ? (status.mode === "cn" ? "中" : "EN")
    : "--"
  readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false
  readonly property bool popoutSwitchClosing: panelLoader.item
    ? panelLoader.item.popoutSwitchClosing === true
    : false

  function localPath(url) {
    var value = String(url || "")
    if (value.indexOf("file://") === 0) value = value.substring(7)
    try { return decodeURIComponent(value) } catch (error) { return value }
  }

  function applyStatus(value) {
    if (!value || typeof value !== "object") return
    // The layer-shell menu briefly owns keyboard focus while it is open, so
    // Fcitx5 may report state 0 even though the application behind it is still
    // the intended target. Preserve that application's last known state until
    // the menu releases focus.
    if (root.opened && Number(value.state || 0) === 0 && root.status.ready === true)
      return
    root.status = value
    if (panelLoader.item && panelLoader.item.applyStatus)
      panelLoader.item.applyStatus(value)
  }

  function refreshStatus() {
    if (root.opened) return
    if (statusProc.running) {
      root.refreshPending = true
      return
    }
    root.refreshPending = false
    statusProc.running = true
  }

  function injectPanel() {
    var target = panelLoader.item
    if (!target) return
    if ("bar" in target) target.bar = root.bar
    if ("settings" in target) target.settings = root.settings
    if ("anchorItem" in target) target.anchorItem = button
    if ("hostWidget" in target) target.hostWidget = root
    if ("controlPath" in target) target.controlPath = root.controlPath
    if (target.applyStatus) target.applyStatus(root.status)
  }

  function open() {
    if (panelLoader.item) panelLoader.item.open()
  }

  function close() {
    if (panelLoader.item) panelLoader.item.close()
  }

  function togglePanel() {
    if (panelLoader.item) panelLoader.item.toggle()
  }

  function closeForPopoutSwitch() {
    if (panelLoader.item) panelLoader.item.closeForPopoutSwitch()
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  onBarChanged: injectPanel()
  onSettingsChanged: injectPanel()
  Component.onCompleted: refreshStatus()

  Loader {
    id: panelLoader
    active: true
    source: Qt.resolvedUrl("Panel.qml")
    visible: false
    onLoaded: {
      root.injectPanel()
      Qt.callLater(root.injectPanel)
    }
  }

  Process {
    id: statusProc
    command: [root.controlPath, "status"]

    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try {
          root.applyStatus(JSON.parse(text || "{}"))
        } catch (error) {
          root.applyStatus({
            ready: false,
            mode: "unknown",
            state: 0,
            inputMethod: "",
            message: "无法读取 Fcitx5 状态"
          })
        }
      }
    }

    onExited: {
      if (root.refreshPending) Qt.callLater(root.refreshStatus)
    }
  }

  // Fcitx5 emits CurrentIM whenever the focused input context changes input
  // method. NameOwnerChanged also catches daemon restarts. The slower timer
  // below remains as a recovery path for clients that do not emit either.
  Process {
    id: eventMonitor
    running: true
    command: [
      "dbus-monitor",
      "--session",
      "--profile",
      "type='signal',interface='org.fcitx.Fcitx.InputContext1',member='CurrentIM'",
      "type='signal',interface='org.freedesktop.DBus',member='NameOwnerChanged',arg0='org.fcitx.Fcitx5'"
    ]

    stdout: SplitParser {
      onRead: function(line) {
        var value = String(line || "")
        if (value.indexOf("\torg.fcitx.Fcitx.InputContext1\tCurrentIM") !== -1
            || value.indexOf("\torg.freedesktop.DBus\tNameOwnerChanged") !== -1)
          eventRefresh.restart()
      }
    }

    onExited: eventMonitorRestart.restart()
  }

  Timer {
    id: eventMonitorRestart
    interval: 1000
    onTriggered: if (!eventMonitor.running) eventMonitor.running = true
  }

  Timer {
    id: eventRefresh
    interval: 40
    onTriggered: root.refreshStatus()
  }

  Connections {
    target: Hyprland

    function onRawEvent(event) {
      if (!event || !event.name) return
      var name = String(event.name)
      if (name === "activewindow" || name === "activewindowv2"
          || name === "focusedmon" || name === "focusedmonv2")
        eventRefresh.restart()
    }
  }

  Timer {
    interval: 2000
    repeat: true
    running: true
    onTriggered: root.refreshStatus()
  }

  IpcHandler {
    target: "io.github.manateelazycat.fcitx-status"

    function refresh(): void { root.broadcast("refreshStatus") }
    function current(): string { return JSON.stringify(root.status) }
    function open(): void { root.open() }
    function close(): void { root.close() }
    function show(): void { root.open() }
    function hide(): void { root.close() }
  }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.label
    fontSize: Style.font.caption
    horizontalMargin: 6
    active: root.status.ready === true && root.status.mode === "cn"
    useActiveColor: false
    tooltipText: root.status.ready === true
      ? (root.status.mode === "cn" ? "中文 · Rime" : "英文 · keyboard-us")
        + "\n右键切换或重启 Fcitx5"
      : String(root.status.message || "Fcitx5 状态未知")

    onPressed: function(buttonCode) {
      if (buttonCode === Qt.RightButton) root.togglePanel()
    }
  }
}
