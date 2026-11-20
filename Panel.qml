import "CompatUi" as ThemeUi
// SPDX-License-Identifier: GPL-3.0-only

import QtQuick
import QtQuick.Controls as Controls
import Quickshell
import Quickshell.Io
import qs.Commons as Commons
import qs.Ui as ShellUi

ThemeUi.Panel {
  id: root
  moduleName: "io.github.manateelazycat.fcitx-status"
  ipcTarget: "io.github.manateelazycat.fcitx-status"
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null
  property string controlPath: ""
  property var status: ({ ready: false, mode: "unknown" })
  property int focusIndex: 0
  property var pendingCommand: []
  property bool actionBusy: false
  property string errorText: ""
  property bool choosingRimeSchema: false
  property var rimeSchemas: []
  property string currentRimeSchema: ""
  property string rimeSchemasError: ""

  readonly property var filteredRimeSchemas: {
    var query = rimeSchemaSearch.text.trim().toLowerCase()
    if (query === "") return root.rimeSchemas
    return root.rimeSchemas.filter(function(schema) {
      return schema.name.toLowerCase().includes(query)
        || schema.id.toLowerCase().includes(query)
    })
  }

  readonly property var barIdentity: hostWidget || root
  readonly property color foreground: root.bar ? root.bar.barForeground : Commons.Color.foreground
  readonly property color urgent: root.bar ? root.bar.urgent : Commons.Color.urgent
  readonly property string fontFamily: root.bar ? root.bar.fontFamily : Commons.Style.font.family

  function applyStatus(value) {
    if (value && typeof value === "object") root.status = value
  }

  function open() {
    root.choosingRimeSchema = false
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
    root.focusIndex = (root.focusIndex + (delta > 0 ? 1 : -1) + menu.count) % menu.count
  }

  function activateFocused() {
    menu.itemAt(root.focusIndex).clicked()
  }

  function showRimeSchemas() {
    if (root.actionBusy || root.controlPath === "") return
    root.rimeSchemas = []
    root.rimeSchemasError = ""
    rimeSchemaSearch.clear()
    root.choosingRimeSchema = true
    picker.forceActiveFocus()
    if (!rimeSchemasProc.running) {
      rimeSchemasProc.command = [root.controlPath, "list-rime-schemas"]
      rimeSchemasProc.running = true
    }
  }

  function showMenu() {
    root.choosingRimeSchema = false
    root.focusIndex = 2
    keyCatcher.forceActiveFocus()
  }

  function selectRimeSchema(index) {
    var schema = root.filteredRimeSchemas[index]
    if (schema) root.queueAction(["set-rime-schema", schema.id])
  }

  function queueAction(args) {
    if (root.actionBusy || root.controlPath === "") return
    root.pendingCommand = [root.controlPath].concat(args)
    root.actionBusy = true
    root.errorText = ""
    // KeyboardPanel owns keyboard focus while open. Release it before invoking
    // fcitx5-remote so the command applies to the previously focused app.
    root.close()
    actionDelay.restart()
  }

  Timer {
    id: actionDelay
    interval: 160
    onTriggered: {
      actionProc.command = root.pendingCommand
      root.pendingCommand = []
      actionProc.running = true
    }
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

  Process {
    id: rimeSchemasProc

    stdout: StdioCollector { id: rimeSchemasOutput }
    stderr: StdioCollector { id: rimeSchemasStderr }

    onExited: function(exitCode) {
      if (exitCode === 0) {
        try {
          var result = JSON.parse(rimeSchemasOutput.text)
          root.currentRimeSchema = result.current
          root.rimeSchemas = result.schemas
        } catch (error) {
          root.rimeSchemasError = "无法读取 Rime 输入方案"
        }
      } else {
        root.rimeSchemasError = String(rimeSchemasStderr.text || "无法读取 Rime 输入方案").trim()
      }
      if (root.opened && root.choosingRimeSchema) rimeSchemaSearch.forceActiveFocus()
    }
  }

  // A deliberately flat menu row. The shared Button component draws theme
  // borders for selected, hovered, and keyboard-cursor states; these rows use
  // background fills for all interaction states.
  component MenuItem: Rectangle {
    id: menuItem

    property string text: ""
    property string iconText: ""
    property bool selected: false
    property bool hasCursor: false
    property color foreground: Commons.Color.foreground
    property string fontFamily: Commons.Style.font.family

    signal clicked()
    signal hovered(bool isHovered)

    implicitHeight: Math.max(Commons.Style.space(34), itemRow.implicitHeight + Commons.Style.space(12))
    radius: Commons.Style.cornerRadius
    opacity: enabled ? 1 : 0.45
    color: itemMouse.pressed
      ? Commons.Style.pressedFillFor(menuItem.foreground, Commons.Color.accent)
      : (menuItem.hasCursor || itemMouse.containsMouse)
        ? Commons.Style.hoverFillFor(menuItem.foreground, menuItem.foreground)
        : menuItem.selected
          ? Commons.Style.selectedFillFor(menuItem.foreground, Commons.Color.accent)
          : "transparent"

    Behavior on color { ColorAnimation { duration: 120 } }

    Row {
      id: itemRow
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      anchors.leftMargin: Commons.Style.space(10)
      anchors.rightMargin: Commons.Style.space(10)
      spacing: Commons.Style.space(8)

      Text {
        width: Commons.Style.space(18)
        text: menuItem.iconText
        color: menuItem.foreground
        font.family: menuItem.fontFamily
        font.pixelSize: Commons.Style.font.body
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
      }

      Text {
        width: Math.max(0, itemRow.width - Commons.Style.space(26))
        text: menuItem.text
        color: menuItem.foreground
        font.family: menuItem.fontFamily
        font.pixelSize: Commons.Style.font.body
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
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

  ThemeUi.KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.barIdentity
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Commons.Style.space(root.choosingRimeSchema ? 400 : 180))
    contentHeight: panel.fittedContentHeight(root.choosingRimeSchema ? picker.implicitHeight : content.implicitHeight)

    ThemeUi.PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      visible: !root.choosingRimeSchema
      blocked: root.actionBusy
      onMoveRequested: function(dx, dy) {
        if (dy !== 0) root.moveFocus(dy)
      }
      onActivateRequested: root.activateFocused()
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onTextKey: function(text) {
        if (text === "c" || text === "C") root.queueAction(["set-mode", "cn"])
        else if (text === "e" || text === "E") root.queueAction(["set-mode", "en"])
        else if (text === "r" || text === "R") root.queueAction(["restart"])
      }

      Column {
        id: content
        width: parent.width
        spacing: Commons.Style.space(4)

        Repeater {
          id: menu
          model: [
            { text: "中文", mode: "cn", args: ["set-mode", "cn"] },
            { text: "英文", mode: "en", args: ["set-mode", "en"] },
            { text: "切换输入法", icon: "⇄" },
            { text: "重启", icon: "↻", args: ["restart"] }
          ]

          MenuItem {
            required property var modelData
            required property int index

            width: content.width
            text: modelData.text
            iconText: selected ? "✓" : (modelData.icon || "")
            selected: root.status.mode === modelData.mode
            hasCursor: root.focusIndex === index
            enabled: !root.actionBusy
            foreground: root.foreground
            fontFamily: root.fontFamily
            onClicked: modelData.args ? root.queueAction(modelData.args) : root.showRimeSchemas()
            onHovered: function(hovered) { if (hovered) root.focusIndex = index }
          }
        }

        Text {
          visible: root.errorText !== ""
          width: parent.width
          text: root.errorText
          color: root.urgent
          font.family: root.fontFamily
          font.pixelSize: Commons.Style.font.caption
          wrapMode: Text.WordWrap
        }
      }
    }

    Item {
      id: picker
      anchors.fill: parent
      visible: root.choosingRimeSchema
      implicitHeight: pickerHeader.implicitHeight
        + Math.min(rimeSchemaList.count, 8) * Commons.Style.space(38)
      Keys.onEscapePressed: root.showMenu()

      Column {
        id: pickerHeader
        width: parent.width
        spacing: Commons.Style.space(4)

        MenuItem {
          width: parent.width
          text: "切换输入方案"
          iconText: "‹"
          foreground: root.foreground
          fontFamily: root.fontFamily
          onClicked: root.showMenu()
        }

        ShellUi.TextField {
          id: rimeSchemaSearch
          width: parent.width
          placeholderText: "搜索输入方案"
          foreground: root.foreground
          accent: Commons.Color.accent
          font.family: root.fontFamily
          readOnly: rimeSchemasProc.running
          selectByMouse: true
          Keys.onUpPressed: rimeSchemaList.decrementCurrentIndex()
          Keys.onDownPressed: rimeSchemaList.incrementCurrentIndex()
          onAccepted: root.selectRimeSchema(rimeSchemaList.currentIndex)
        }

        Text {
          visible: rimeSchemaList.count === 0
          width: parent.width
          text: rimeSchemasProc.running ? "正在读取输入方案…"
            : root.rimeSchemasError || (root.rimeSchemas.length ? "没有匹配的输入方案" : "没有可用的输入方案")
          color: root.rimeSchemasError === "" ? root.foreground : root.urgent
          font.family: root.fontFamily
          font.pixelSize: Commons.Style.font.caption
          wrapMode: Text.Wrap
        }
      }

      ListView {
        id: rimeSchemaList
        anchors.top: pickerHeader.bottom
        anchors.topMargin: count > 0 ? Commons.Style.space(4) : 0
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        clip: true
        spacing: Commons.Style.space(4)
        model: root.filteredRimeSchemas
        onModelChanged: {
          currentIndex = count > 0 ? 0 : -1
          positionViewAtBeginning()
        }
        Controls.ScrollBar.vertical: Controls.ScrollBar {}

        delegate: MenuItem {
          required property var modelData
          required property int index

          width: rimeSchemaList.width - Commons.Style.space(8)
          text: modelData.name
          iconText: selected ? "✓" : ""
          selected: modelData.id === root.currentRimeSchema
          hasCursor: ListView.isCurrentItem
          enabled: !root.actionBusy
          foreground: root.foreground
          fontFamily: root.fontFamily
          onClicked: root.selectRimeSchema(index)
        }
      }
    }
  }
}
