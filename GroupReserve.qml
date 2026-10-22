import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

// Loaded while style is "group": puts every labelled window in a group of its
// own, so Hyprland reserves a groupbar strip above it (the window shrinks
// instead of being covered), and styles/Group.qml paints the label there.
//
// While active, group.auto_group is off, or a window opened from a labelled
// one would tab into its group. Hyprland only has a global group lock
// (group.lock ignores `window`), so locking each group is not an option.
Item {
  id: reserve

  property var labels: ({})

  // Height from the window's top edge up to the top of the groupbar; read
  // from the live config so a theme's groupbar size is respected.
  property real strip: 0
  property real border: 0

  // Addresses grouped by this module, so it never ungroups the user's own groups.
  property var ours: ({})
  property bool autoGroupWas: true

  function dispatch(lua) { Hyprland.dispatch(lua) }

  // The ipc snapshot lags Hyprland, so each window is grouped once (`ours`
  // marks it) and ungrouping re-checks live state in a detached hyprctl run,
  // which also outlives this object when the style switches away.
  function sync() {
    var wins = Hyprland.toplevels.values
    var drop = []
    for (var i = 0; i < wins.length; i++) {
      var ipc = wins[i].lastIpcObject || {}
      if (!ipc.address) continue
      var grouped = (ipc.grouped || []).length
      var want = !!labels[ipc.address]
      if (want && grouped === 0 && !ours[ipc.address]) {
        ours[ipc.address] = true
        dispatch('hl.dsp.group.toggle({ window = "address:' + ipc.address + '" })')
      } else if (want && grouped === 1) {
        ours[ipc.address] = true  // also adopts groups from an earlier shell run
      } else if (!want && ours[ipc.address]) {
        delete ours[ipc.address]
        drop.push(ipc.address)
      }
    }
    if (drop.length) ungroup(drop, "")
  }

  // Dissolve the given single-window groups after Hyprland settles, then run `after`.
  function ungroup(addrs, after) {
    Quickshell.execDetached(["sh", "-c",
      'sleep 0.3; for a; do ' +
      'hyprctl clients -j | jq -e --arg a "$a" \'any(.[]; .address == $a and (.grouped | length) == 1)\' >/dev/null && ' +
      'hyprctl dispatch "hl.dsp.group.toggle({ window = \\"address:$a\\" })" >/dev/null; done; ' + after,
      "ungroup"].concat(addrs))
  }

  onLabelsChanged: sync()

  Connections {
    target: Hyprland
    // ponytail: debounced resync on any event; the ipc snapshot lags the event
    function onRawEvent(event) { resync.restart() }
  }

  Timer {
    id: resync
    interval: 150
    onTriggered: reserve.sync()
  }

  Process {
    id: probe
    running: true
    command: ["sh", "-c",
      "for o in general:border_size group:groupbar:height group:groupbar:indicator_height " +
      "group:groupbar:indicator_gap group:auto_group; do hyprctl getoption \"$o\" -j; done | jq -s -c ."]
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          var v = JSON.parse(text).map(o => o.int !== undefined ? o.int : o.bool)
          reserve.border = v[0]
          reserve.strip = v[0] + v[1] + v[2] + v[3]
          reserve.autoGroupWas = v[4] !== false && v[4] !== 0
        } catch (e) {
          reserve.border = 2
          reserve.strip = 30
        }
        Quickshell.execDetached(["hyprctl", "eval", "hl.config({ group = { auto_group = false } })"])
        reserve.sync()
      }
    }
  }

  Component.onDestruction: {
    ungroup(Object.keys(ours),
      "hyprctl eval 'hl.config({ group = { auto_group = " + (autoGroupWas ? "true" : "false") + " } })' >/dev/null")
  }
}
