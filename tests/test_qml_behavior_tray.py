import unittest

from qml_harness import HAVE_SESSION, parse_behave, qml_url, require_no_qml_errors, run_quickshell


@unittest.skipUnless(HAVE_SESSION, "needs a quickshell binary and a Wayland session")
class QmlTrayBehaviorTests(unittest.TestCase):
    def test_navigator_tracks_levels_and_settles_level_changes(self):
        qml = f"""
import Quickshell
import QtQuick

ShellRoot {{
  id: shell
  property var navigator: null
  property bool rejectedDuringSettling: false

  Component {{
    id: fakeOpenerComponent
    QtObject {{
      property var menu: null
      readonly property var children: menu ? menu.children : []
    }}
  }}

  Component.onCompleted: {{
    var component = Qt.createComponent("{qml_url('lacuna.tray/TrayMenuNavigator.qml')}", Component.PreferSynchronous)
    if (component.status !== Component.Ready) {{
      console.log("BEHAVE_ERR " + component.errorString())
      Qt.quit()
      return
    }}
    navigator = component.createObject(shell, {{
      openerComponent: fakeOpenerComponent,
      openerOwner: shell,
      rootChildren: [{{ id: "root" }}],
      settleDuration: 40
    }})
    navigator.enterSubmenu({{ id: "first", children: [{{ id: "first-child" }}] }}, "First")
    rejectedDuringSettling = !navigator.enterSubmenu({{ id: "blocked", children: [] }}, "Blocked")
    phaseOne.restart()
  }}

  Timer {{
    id: phaseOne
    interval: 55
    onTriggered: {{
      var allowedAfterFirst = shell.navigator.inputAllowed()
      shell.navigator.enterSubmenu({{ id: "second", children: [{{ id: "second-child" }}] }}, "Second")
      var entered = {{
        depth: shell.navigator.depth,
        title: shell.navigator.currentTitle,
        child: shell.navigator.currentChildren[0].id,
        settling: shell.navigator.inputSettling,
        allowed: shell.navigator.inputAllowed()
      }}
      phaseTwo.entered = entered
      phaseTwo.allowedAfterFirst = allowedAfterFirst
      phaseTwo.restart()
    }}
  }}

  Timer {{
    id: phaseTwo
    property var entered: ({{}})
    property bool allowedAfterFirst: false
    interval: 55
    onTriggered: {{
      var allowedAfterSecond = shell.navigator.inputAllowed()
      shell.navigator.leaveSubmenu()
      var left = {{
        depth: shell.navigator.depth,
        title: shell.navigator.currentTitle,
        settling: shell.navigator.inputSettling,
        allowed: shell.navigator.inputAllowed()
      }}
      phaseThree.entered = entered
      phaseThree.left = left
      phaseThree.allowedAfterFirst = allowedAfterFirst
      phaseThree.allowedAfterSecond = allowedAfterSecond
      phaseThree.restart()
    }}
  }}

  Timer {{
    id: phaseThree
    property var entered: ({{}})
    property var left: ({{}})
    property bool allowedAfterFirst: false
    property bool allowedAfterSecond: false
    interval: 55
    onTriggered: {{
      console.log("BEHAVE " + JSON.stringify({{
        entered: entered,
        left: left,
        allowedAfterFirst: allowedAfterFirst,
        allowedAfterSecond: allowedAfterSecond,
        allowedAfterLeave: shell.navigator.inputAllowed(),
        rejectedDuringSettling: shell.rejectedDuringSettling
      }}))
      Qt.quit()
    }}
  }}
}}
"""
        output = run_quickshell(qml)
        require_no_qml_errors(output)
        row = parse_behave(output)[0]
        self.assertTrue(row["rejectedDuringSettling"], output[-2000:])
        self.assertTrue(row["allowedAfterFirst"], output[-2000:])
        self.assertTrue(row["allowedAfterSecond"], output[-2000:])
        self.assertEqual(2, row["entered"]["depth"])
        self.assertEqual("Second", row["entered"]["title"])
        self.assertEqual("second-child", row["entered"]["child"])
        self.assertTrue(row["entered"]["settling"])
        self.assertFalse(row["entered"]["allowed"])
        self.assertEqual(1, row["left"]["depth"])
        self.assertEqual("First", row["left"]["title"])
        self.assertTrue(row["left"]["settling"])
        self.assertFalse(row["left"]["allowed"])
        self.assertTrue(row["allowedAfterLeave"], output[-2000:])

    def test_invalidation_and_root_reset_prune_deepest_first(self):
        qml = f"""
import Quickshell
import QtQuick

ShellRoot {{
  id: shell
  property var navigator: null
  property var destroyLog: []

  function recordDestroy(name) {{
    var next = destroyLog.slice()
    next.push({{ name: name, depth: navigator ? navigator.depth : -1 }})
    destroyLog = next
  }}

  Component {{
    id: fakeOpenerComponent
    QtObject {{
      property var menu: null
      property string retainedId: ""
      readonly property var children: menu ? menu.children : []
      Component.onCompleted: retainedId = String(menu.id)
      Component.onDestruction: {{
        menu = null
        shell.recordDestroy(retainedId)
      }}
    }}
  }}

  Component.onCompleted: {{
    var component = Qt.createComponent("{qml_url('lacuna.tray/TrayMenuNavigator.qml')}", Component.PreferSynchronous)
    if (component.status !== Component.Ready) {{
      console.log("BEHAVE_ERR " + component.errorString())
      Qt.quit()
      return
    }}
    navigator = component.createObject(shell, {{
      openerComponent: fakeOpenerComponent,
      openerOwner: shell,
      settleDuration: 20
    }})
    navigator.enterSubmenu({{ id: "first", children: [] }}, "First")
    enterSecond.restart()
  }}

  Timer {{
    id: enterSecond
    interval: 30
    onTriggered: {{
      shell.navigator.enterSubmenu({{ id: "second-a", children: [] }}, "Second A")
      invalidateCurrent.restart()
    }}
  }}

  Timer {{
    id: invalidateCurrent
    interval: 30
    onTriggered: {{
      shell.navigator.levels[1].opener.menu = null
      ancestorPhase.currentDepth = shell.navigator.depth
      ancestorPhase.currentTitle = shell.navigator.currentTitle
      ancestorPhase.restart()
    }}
  }}

  Timer {{
    id: ancestorPhase
    property int currentDepth: -1
    property string currentTitle: ""
    interval: 30
    onTriggered: {{
      shell.navigator.enterSubmenu({{ id: "second-b", children: [] }}, "Second B")
      invalidateAncestor.currentDepth = currentDepth
      invalidateAncestor.currentTitle = currentTitle
      invalidateAncestor.restart()
    }}
  }}

  Timer {{
    id: invalidateAncestor
    property int currentDepth: -1
    property string currentTitle: ""
    interval: 30
    onTriggered: {{
      shell.navigator.levels[0].opener.menu = null
      resetPhase.currentDepth = currentDepth
      resetPhase.currentTitle = currentTitle
      resetPhase.ancestorDepth = shell.navigator.depth
      resetPhase.restart()
    }}
  }}

  Timer {{
    id: resetPhase
    property int currentDepth: -1
    property string currentTitle: ""
    property int ancestorDepth: -1
    interval: 30
    onTriggered: {{
      shell.navigator.enterSubmenu({{ id: "reset-parent", children: [] }}, "Reset Parent")
      resetChildren.restart()
    }}
  }}

  Timer {{
    id: resetChildren
    interval: 30
    onTriggered: {{
      shell.navigator.enterSubmenu({{ id: "reset-child", children: [] }}, "Reset Child")
      finishReset.restart()
    }}
  }}

  Timer {{
    id: finishReset
    interval: 30
    onTriggered: {{
      shell.navigator.resetForRoot({{ id: "next-root" }})
      report.restart()
    }}
  }}

  Timer {{
    id: report
    interval: 30
    onTriggered: {{
      console.log("BEHAVE " + JSON.stringify({{
        currentDepth: resetPhase.currentDepth,
        currentTitle: resetPhase.currentTitle,
        ancestorDepth: resetPhase.ancestorDepth,
        finalDepth: shell.navigator.depth,
        rootId: shell.navigator.rootIdentity.id,
        settling: shell.navigator.inputSettling,
        destroyLog: shell.destroyLog
      }}))
      Qt.quit()
    }}
  }}
}}
"""
        output = run_quickshell(qml)
        require_no_qml_errors(output)
        row = parse_behave(output)[0]
        self.assertEqual(1, row["currentDepth"])
        self.assertEqual("First", row["currentTitle"])
        self.assertEqual(0, row["ancestorDepth"])
        self.assertEqual(0, row["finalDepth"])
        self.assertEqual("next-root", row["rootId"])
        self.assertFalse(row["settling"])
        self.assertEqual(
            ["second-a", "second-b", "first", "reset-child", "reset-parent"],
            [entry["name"] for entry in row["destroyLog"]],
        )
        self.assertTrue(all(entry["depth"] == 0 for entry in row["destroyLog"][-2:]))


if __name__ == "__main__":
    unittest.main()
