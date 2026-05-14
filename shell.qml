import Quickshell
import "modules"
import "services"

Scope {
  LacunaMenuState {
    id: lacunaMenuState
  }

  LacunaBar {
    menuState: lacunaMenuState
  }

  LacunaMenu {
    menuState: lacunaMenuState
  }
}
