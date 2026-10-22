import QtQuick
import qs.Commons

// A strip across the full width of the window, top or bottom edge; the
// label sits left, centre or right per `position`.
// The loader sets: host (the window rect), label, options (resolved), fill, ink.
Rectangle {
  id: bar
  property Item host
  property string label
  property var options
  property color fill
  property color ink

  readonly property real hw: host ? host.width : 0
  readonly property real hh: host ? host.height : 0

  readonly property string position: String(options.position)
  readonly property string side: position.split("-")[1] || "right"

  x: 0
  y: position.indexOf("bottom") === 0 ? hh - height : 0
  width: hw
  height: text.implicitHeight + 6
  opacity: Number(options.opacity)
  color: fill

  Text {
    id: text
    anchors.verticalCenter: parent.verticalCenter
    x: bar.side === "left" ? 10
      : bar.side === "center" ? (bar.width - width) / 2
      : bar.width - width - 10
    width: Math.min(implicitWidth, bar.width - 20)
    elide: Text.ElideMiddle
    text: bar.label
    color: bar.ink
    font.family: Style.fontFamily
    font.pixelSize: Number(bar.options.fontSize)
    font.bold: true
  }
}
