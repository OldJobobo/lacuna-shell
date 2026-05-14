import Quickshell
import "modules"
import "services"

Scope {
  LacunaMenuState {
    id: lacunaMenuState
  }

  CompactState {
    id: compactState
  }

  LacunaBar {
    menuState: lacunaMenuState
    sharedCompactState: compactState
  }

  LacunaMenu {
    menuState: lacunaMenuState
    sharedCompactState: compactState
  }
}
