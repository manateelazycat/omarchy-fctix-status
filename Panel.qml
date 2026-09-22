// SPDX-License-Identifier: GPL-3.0-only

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

Panel {
  id: root
  moduleName: "io.github.manateelazycat.fcitx-status"
  ipcTarget: "io.github.manateelazycat.fcitx-status"
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null
  property string controlPath: ""
  property var status: ({ ready: false, mode: "unknown" })
  property int focusIndex: 0
  property string pendingAction: ""
  property bool actionBusy: false
  property string errorText: ""

  readonly property var barIdentity: hostWidget || root
  readonly property color foreground: root.bar ? root.bar.barForeground : Color.foreground
  readonly property color urgent: root.bar ? root.bar.urgent : Color.urgent
  readonly property string fontFamily: root.bar ? root.bar.fontFamily : Style.font.family

  function applyStatus(value) {
    if (value && typeof value === "object") root.status = value
  }

  function open() {
    root.controller.show()
    root.focusIndex = root.status.mode === "en" ? 1 : 0
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }

  function close() {
    root.controller.hide()
  }

  function toggle() {
    if (root.opened) root.close()
    else {
      root.errorText = ""
      root.open()
    }
  }

  function switchPanel(direction) {
    if (root.bar && typeof root.bar.switchPanelFrom === "function")
      return root.bar.switchPanelFrom(root.barIdentity, direction)
    return false
  }

  function moveFocus(delta) {
    root.focusIndex = (root.focusIndex + (delta > 0 ? 1 : -1) + 3) % 3
  }

  function activateFocused() {
    if (root.focusIndex === 0) root.queueAction("cn")
    else if (root.focusIndex === 1) root.queueAction("en")
    else root.queueAction("restart")
  }

  function queueAction(action) {
    if (root.actionBusy || root.controlPath === "") return
    root.pendingAction = action
    root.actionBusy = true
    root.errorText = ""
    // KeyboardPanel owns keyboard focus while open. Release it before invoking
    // fcitx5-remote so the command applies to the previously focused app.
    root.close()
    actionDelay.restart()
  }

  function runPendingAction() {
    var action = root.pendingAction
    root.pendingAction = ""
    if (action === "cn" || action === "en")
      actionProc.command = [root.controlPath, "set-mode", action]
    else
      actionProc.command = [root.controlPath, "restart"]
    actionProc.running = true
  }

  Timer {
    id: actionDelay
    interval: 160
    onTriggered: root.runPendingAction()
  }

  Timer {
    id: refreshAfterAction
    interval: 200
    onTriggered: {
      if (root.hostWidget && root.hostWidget.broadcast)
        root.hostWidget.broadcast("refreshStatus")
    }
  }

  Process {
    id: actionProc

    stderr: StdioCollector {
      id: actionError
      waitForEnd: true
    }

    onExited: function(exitCode) {
      root.actionBusy = false
      refreshAfterAction.restart()
      if (exitCode !== 0) {
        root.errorText = String(actionError.text || "Fcitx5 操作失败").trim()
        root.open()
      }
    }
  }

  // A deliberately flat menu row. The shared Button component draws theme
  // borders for selected, hovered, and keyboard-cursor states; these rows use
  // background fills only so none of the three menu items ever gets an outline.
  component MenuItem: Rectangle {
    id: menuItem

    property string text: ""
    property string iconText: ""
    property bool selected: false
    property bool hasCursor: false
    property color foreground: Color.foreground
    property string fontFamily: Style.font.family

    signal clicked()
    signal hovered(bool isHovered)

    implicitHeight: Math.max(Style.space(34), itemRow.implicitHeight + Style.space(12))
    radius: Style.cornerRadius
    opacity: enabled ? 1 : 0.45
    color: itemMouse.pressed
      ? Style.pressedFillFor(menuItem.foreground, Color.accent)
      : (menuItem.hasCursor || itemMouse.containsMouse)
        ? Style.hoverFillFor(menuItem.foreground, menuItem.foreground)
        : menuItem.selected
          ? Style.selectedFillFor(menuItem.foreground, Color.accent)
          : "transparent"

    Behavior on color { ColorAnimation { duration: 120 } }

    Row {
      id: itemRow
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      anchors.leftMargin: Style.space(10)
      anchors.rightMargin: Style.space(10)
      spacing: Style.space(8)

      Text {
        width: Style.space(18)
        text: menuItem.iconText
        color: menuItem.foreground
        font.family: menuItem.fontFamily
        font.pixelSize: Style.font.body
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
      }

      Text {
        text: menuItem.text
        color: menuItem.foreground
        font.family: menuItem.fontFamily
        font.pixelSize: Style.font.body
        verticalAlignment: Text.AlignVCenter
      }
    }

    MouseArea {
      id: itemMouse
      anchors.fill: parent
      enabled: menuItem.enabled
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: menuItem.clicked()
      onEntered: menuItem.hovered(true)
      onExited: menuItem.hovered(false)
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.barIdentity
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(180))
    contentHeight: panel.fittedContentHeight(content.implicitHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      blocked: root.actionBusy
      onMoveRequested: function(dx, dy) {
        if (dy !== 0) root.moveFocus(dy)
      }
      onActivateRequested: root.activateFocused()
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onTextKey: function(text) {
        if (text === "c" || text === "C") root.queueAction("cn")
        else if (text === "e" || text === "E") root.queueAction("en")
        else if (text === "r" || text === "R") root.queueAction("restart")
      }

      Column {
        id: content
        width: parent.width
        spacing: Style.space(4)

        MenuItem {
          width: parent.width
          text: "中文"
          iconText: root.status.mode === "cn" ? "✓" : ""
          selected: root.status.mode === "cn"
          hasCursor: root.focusIndex === 0
          enabled: !root.actionBusy
          foreground: root.foreground
          fontFamily: root.fontFamily
          onClicked: root.queueAction("cn")
          onHovered: function(hovered) { if (hovered) root.focusIndex = 0 }
        }

        MenuItem {
          width: parent.width
          text: "英文"
          iconText: root.status.mode === "en" ? "✓" : ""
          selected: root.status.mode === "en"
          hasCursor: root.focusIndex === 1
          enabled: !root.actionBusy
          foreground: root.foreground
          fontFamily: root.fontFamily
          onClicked: root.queueAction("en")
          onHovered: function(hovered) { if (hovered) root.focusIndex = 1 }
        }

        MenuItem {
          width: parent.width
          text: "重启"
          iconText: "↻"
          hasCursor: root.focusIndex === 2
          enabled: !root.actionBusy
          foreground: root.foreground
          fontFamily: root.fontFamily
          onClicked: root.queueAction("restart")
          onHovered: function(hovered) { if (hovered) root.focusIndex = 2 }
        }

        Text {
          visible: root.errorText !== ""
          width: parent.width
          text: root.errorText
          color: root.urgent
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          wrapMode: Text.WordWrap
        }
      }
    }
  }
}
