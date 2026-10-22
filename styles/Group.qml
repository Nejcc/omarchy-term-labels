import QtQuick

// Bar painted over the groupbar strip that GroupReserve.qml makes Hyprland
// reserve above the window, so it covers no window content.
// The loader also sets: strip (window top edge -> groupbar top) and border.
Bar {
  property real strip: 0
  property real border: 0

  visible: host !== null && host.grouped && strip > 0
  y: -strip
  height: strip - border
}
