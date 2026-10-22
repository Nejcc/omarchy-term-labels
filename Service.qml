import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.Commons

// Draws a ribbon with the window's label on every labelled window on each
// monitor's active workspace. Labels live in ~/.local/state/term-labels.json
// ({ "0xaddress": "name" }), written by bin/tlabel.
//
// Options go on this plugin's entry in ~/.config/omarchy/shell.json, e.g.
//   { "id": "nejcc.term-labels", "position": "top-right", "color": "auto" }
// The shell hands services no settings, so the file is read directly.
Item {
  id: root

  property var labels: ({})
  property var options: ({})

  readonly property var defaults: ({
    style: "ribbon",        // ribbon | bar (full width, over the window) | group (full width, above it)
    position: "top-right",  // top|bottom - left|center|right
    color: "auto",          // auto (hue per label) | accent | #rrggbb
    textColor: "auto",      // auto | #rrggbb
    fontSize: 12,
    margin: 0,              // ribbon: gap from the window edges; 0 sits flush
    opacity: 0.95
  })

  // defaults overlaid with the shell.json entry; what style modules receive
  readonly property var resolved: {
    var out = {}
    for (var k in defaults) {
      var v = options[k]
      out[k] = v === undefined || v === null || v === "" ? defaults[k] : v
    }
    return out
  }

  function opt(name) { return resolved[name] }

  // One file per look in styles/; a new look is a new file.
  readonly property var styles: ({ ribbon: "styles/Ribbon.qml", bar: "styles/Bar.qml", group: "styles/Group.qml" })
  readonly property url styleUrl: Qt.resolvedUrl(styles[opt("style")] || styles.ribbon)

  // style "group" also needs Hyprland to reserve room above each window
  Loader {
    id: groupReserve
    active: root.opt("style") === "group"
    source: "GroupReserve.qml"
    onLoaded: item.labels = Qt.binding(() => root.labels)
  }

  FileView {
    id: labelsFile
    path: Quickshell.env("HOME") + "/.local/state/term-labels.json"
    watchChanges: true
    onFileChanged: reload()
    onLoaded: {
      try { root.labels = JSON.parse(text()) } catch (e) { root.labels = {} }
      Hyprland.refreshToplevels()
    }
    // the file appears on the first `tlabel`; a missing file is not watched
    onLoadFailed: { root.labels = {}; retry.start() }
  }

  Timer {
    id: retry
    interval: 3000
    onTriggered: labelsFile.reload()
  }

  FileView {
    path: Quickshell.env("HOME") + "/.config/omarchy/shell.json"
    watchChanges: true
    onFileChanged: reload()
    onLoaded: {
      try {
        root.options = (JSON.parse(text()).plugins || []).find(p => p.id === "nejcc.term-labels") || {}
      } catch (e) {}  // keep the last good options while the file is mid-edit
    }
  }

  // ponytail: refresh geometry on every Hyprland event; a mouse-drag resize
  // emits none, so the ribbon catches up on the next event
  Connections {
    target: Hyprland
    function onRawEvent(event) {
      if (Object.keys(root.labels).length > 0) Hyprland.refreshToplevels()
    }
  }

  // Same label -> same colour, so a session keeps its colour across moves.
  function hue(text) {
    var h = 0
    for (var i = 0; i < text.length; i++) h = (h * 31 + text.charCodeAt(i)) % 360
    return h / 360
  }

  function fill(label) {
    var c = opt("color")
    if (c === "auto") return Qt.hsla(hue(label), 0.65, 0.6, 1)
    if (c === "accent") return Color.accent
    return c
  }

  function ink() {
    var c = opt("textColor")
    if (c !== "auto") return c
    return opt("color") === "accent" ? Color.background : "#111111"
  }

  Variants {
    model: Quickshell.screens

    PanelWindow {
      // not `layer`: inside a delegate that name resolves to Item.layer
      id: overlay
      required property var modelData
      readonly property var hyprMonitor: Hyprland.monitors.values.find(m => m.name === modelData.name) || null

      screen: modelData
      anchors { top: true; bottom: true; left: true; right: true }
      color: "transparent"
      exclusionMode: ExclusionMode.Ignore
      WlrLayershell.layer: WlrLayer.Top
      WlrLayershell.namespace: "term-labels"
      mask: Region {}

      Repeater {
        model: Hyprland.toplevels

        // Positioned on the window; the style module draws inside it.
        delegate: Item {
          id: win
          required property var modelData
          readonly property var ipc: modelData.lastIpcObject || ({})
          readonly property string label: (ipc.address && root.labels[ipc.address]) || ""
          readonly property bool grouped: (ipc.grouped || []).length > 0

          visible: !!(label !== "" && ipc.at !== undefined && ipc.workspace !== undefined
            && overlay.hyprMonitor && overlay.hyprMonitor.activeWorkspace
            && ipc.workspace.id === overlay.hyprMonitor.activeWorkspace.id)
          x: visible ? ipc.at[0] - overlay.modelData.x : 0
          y: visible ? ipc.at[1] - overlay.modelData.y : 0
          width: visible ? ipc.size[0] : 0
          height: visible ? ipc.size[1] : 0

          Loader {
            active: win.visible
            source: root.styleUrl
            onLoaded: {
              item.host = win
              item.label = Qt.binding(() => win.label)
              item.options = Qt.binding(() => root.resolved)
              item.fill = Qt.binding(() => root.fill(win.label))
              item.ink = Qt.binding(() => root.ink())
              if ("strip" in item) {
                item.strip = Qt.binding(() => groupReserve.item ? groupReserve.item.strip : 0)
                item.border = Qt.binding(() => groupReserve.item ? groupReserve.item.border : 0)
              }
            }
          }
        }
      }
    }
  }
}
