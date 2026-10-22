import QtQuick
import qs.Commons

// A tag in one corner (or edge centre) of the window.
// The loader sets: host (the window rect), label, options (resolved), fill, ink.
Rectangle {
  id: ribbon
  property Item host
  property string label
  property var options
  property color fill
  property color ink

  readonly property real hw: host ? host.width : 0
  readonly property real hh: host ? host.height : 0

  readonly property string position: String(options.position)
  readonly property bool atBottom: position.indexOf("bottom") === 0
  readonly property string side: position.split("-")[1] || "right"
  readonly property real margin: Number(options.margin)
  readonly property bool flush: margin === 0
  readonly property real r: 6

  x: side === "left" ? margin
    : side === "center" ? (hw - width) / 2
    : hw - width - margin
  y: atBottom ? hh - height - margin : margin
  width: text.implicitWidth + 20
  height: text.implicitHeight + 6
  opacity: Number(options.opacity)
  color: fill

  // Flush against the window: square the corners that touch its edges.
  topLeftRadius: flush && (!atBottom || side === "left") ? 0 : r
  topRightRadius: flush && (!atBottom || side === "right") ? 0 : r
  bottomLeftRadius: flush && (atBottom || side === "left") ? 0 : r
  bottomRightRadius: flush && (atBottom || side === "right") ? 0 : r

  Text {
    id: text
    anchors.centerIn: parent
    text: ribbon.label
    color: ribbon.ink
    font.family: Style.fontFamily
    font.pixelSize: Number(ribbon.options.fontSize)
    font.bold: true
  }
}
