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

  SidebarState {
    id: sidebarState
  }

  LacunaBar {
    menuState: lacunaMenuState
    sharedCompactState: compactState
    sharedSidebarState: sidebarState
  }

  LacunaMenu {
    menuState: lacunaMenuState
    sharedCompactState: compactState
    sharedSidebarState: sidebarState
  }
}
