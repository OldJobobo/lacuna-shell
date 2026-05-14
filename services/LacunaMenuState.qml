import QtQuick

Item {
  id: root

  property bool open: false
  property var stack: ["main"]
  readonly property string currentView: stack.length > 0 ? stack[stack.length - 1] : "main"

  function show() {
    open = true
  }

  function close() {
    open = false
    stack = ["main"]
  }

  function toggle() {
    if (open) close()
    else show()
  }

  function push(view) {
    if (!view) return
    stack = stack.concat([view])
  }

  function back() {
    if (stack.length <= 1) {
      close()
      return
    }

    stack = stack.slice(0, stack.length - 1)
  }
}
