import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

// Shotline -- bar widget.
//
// Two icons: the camera shows the running session with its counter, the pen
// only appears once there is a shot to annotate. Clicking the pen opens the
// screenshot in the editor and leads back into the comment afterwards.
//
//   Camera  left: next shot      middle: discard last   right: menu
//   Pen     left: annotate       middle: menu           right: blur out
//
// State comes from `shotline status --json`; the CLI nudges the widget over
// IPC after every change, the timer is only the safety net.
BarWidget {
  id: root
  moduleName: "olivgrau.shotline"

  property bool active: false
  property int count: 0
  property string title: ""
  property bool canAnnotate: false

  readonly property bool hideWhenIdle: setting("hideWhenIdle", false)
  readonly property bool showCount: setting("showCount", true)
  readonly property bool showPen: setting("showPen", true)

  // Qt.resolvedUrl(".") is this file's directory, so the widget finds the CLI
  // inside its own plugin folder without needing it on $PATH.
  readonly property string pluginDir:
    Qt.resolvedUrl(".").toString().replace(/^file:\/\//, "")
  readonly property string cli: setting("command", pluginDir + "bin/shotline")

  // Nerd Font glyphs: camera and pen.
  readonly property string cameraIcon: "\uf030"   // Kamera
  readonly property string penIcon: "\uf040"      // Stift
  readonly property string activeDot: "●"

  function parseStatus(text) {
    try {
      var data = JSON.parse(String(text))
      root.active = data.active === true
      root.count = data.count || 0
      root.title = data.title || ""
      root.canAnnotate = data.canAnnotate === true
    } catch (e) {
      root.active = false
      root.count = 0
      root.canAnnotate = false
    }
  }

  function run(args) {
    if (root.bar) root.bar.run(root.cli + " " + args)
    refreshSoon.restart()
  }

  function refresh() {
    if (!status.running) status.running = true
  }

  function pressCamera(button) {
    if (button === Qt.RightButton) root.run("menu")
    else if (button === Qt.MiddleButton) { if (root.active) root.run("undo") }
    else root.run("shot")
  }

  function pressPen(button) {
    if (button === Qt.RightButton) root.run("annotate --blur")
    else if (button === Qt.MiddleButton) root.run("menu")
    else root.run("annotate")
  }

  readonly property string cameraText: {
    if (!root.active) return cameraIcon
    return root.showCount ? cameraIcon + " " + root.count : cameraIcon + " " + activeDot
  }

  readonly property bool penVisible: root.showPen && root.canAnnotate
  readonly property bool cameraVisible: root.active || !root.hideWhenIdle

  implicitWidth: root.vertical
    ? Math.max(cameraButton.implicitWidth, penVisible ? penButton.implicitWidth : 0)
    : (cameraVisible ? cameraButton.implicitWidth : 0) + (penVisible ? penButton.implicitWidth : 0)
  implicitHeight: root.vertical
    ? (cameraVisible ? cameraButton.implicitHeight : 0) + (penVisible ? penButton.implicitHeight : 0)
    : Math.max(cameraButton.implicitHeight, penVisible ? penButton.implicitHeight : 0)

  Process {
    id: status
    command: [root.cli, "status", "--json"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.parseStatus(text)
    }
  }

  Timer {
    interval: 2000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: if (!status.running) status.running = true
  }

  // After a click, the selection or the editor can take any amount of time. A
  // short follow-up covers the case where the CLI never sends its IPC nudge.
  Timer {
    id: refreshSoon
    interval: 1500
    repeat: false
    onTriggered: root.refresh()
  }

  IpcHandler {
    target: "olivgrau.shotline"

    function refresh(): void { root.refresh() }
    function shot(): void { root.run("shot") }
    function menu(): void { root.run("menu") }
    function annotate(): void { root.run("annotate") }
    function finish(): void { root.run("finish --open") }
  }


  Row {
    id: horizontal
    visible: !root.vertical
    spacing: 0

    WidgetButton {
      id: cameraButton
      visible: root.cameraVisible
      bar: root.bar
      text: root.cameraText
      labelVisible: true
      hasVisualContent: root.cameraVisible && text !== ""
      horizontalMargin: 8.75
      verticalPadding: 8.75
      tooltipText: root.active
        ? "Shotline\n" + root.count + " shot(s)" + (root.title !== "" ? " -- " + root.title : "")
          + "\nleft: next shot\nmiddle: discard last\nright: menu"
        : "Shotline\nno session\nleft: take the first shot\nright: menu"

      onPressed: function (b) { root.pressCamera(b) }
    }

    WidgetButton {
      id: penButton
      visible: root.penVisible
      bar: root.bar
      text: root.penIcon
      labelVisible: true
      hasVisualContent: root.penVisible
      horizontalMargin: 7
      verticalPadding: 8.75
      tooltipText: "Annotate shot " + root.count + "\nleft: pen\nright: blur out\nmiddle: menu"

      onPressed: function (b) { root.pressPen(b) }
    }
  }

  Column {
    id: verticalStack
    visible: root.vertical
    spacing: 0

    WidgetButton {
      id: cameraButtonVertical
      visible: root.cameraVisible
      bar: root.bar
      labelVisible: false
      hasVisualContent: root.cameraVisible
      fixedHeight: (root.active && root.showCount ? 2 : 1) * Style.bar.iconSlot
      horizontalMargin: 8.75
      verticalPadding: 8.75
      tooltipText: cameraButton.tooltipText

      onPressed: function (b) { root.pressCamera(b) }

      Column {
        anchors.fill: parent

        Repeater {
          model: root.active && root.showCount ? [root.cameraIcon, String(root.count)] : [root.cameraIcon]

          OpticalGlyph {
            required property string modelData
            width: cameraButtonVertical.width
            height: Style.bar.iconSlot
            text: modelData
            fontFamily: cameraButtonVertical.fontFamily
            fontSize: cameraButtonVertical.fontSize
            color: cameraButtonVertical.foreground
          }
        }
      }
    }

    WidgetButton {
      id: penButtonVertical
      visible: root.penVisible
      bar: root.bar
      labelVisible: false
      hasVisualContent: root.penVisible
      fixedHeight: Style.bar.iconSlot
      horizontalMargin: 7
      verticalPadding: 8.75
      tooltipText: penButton.tooltipText

      onPressed: function (b) { root.pressPen(b) }

      OpticalGlyph {
        anchors.fill: parent
        text: root.penIcon
        fontFamily: penButtonVertical.fontFamily
        fontSize: penButtonVertical.fontSize
        color: penButtonVertical.foreground
      }
    }
  }
}
