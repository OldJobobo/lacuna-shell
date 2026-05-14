import Quickshell
import Quickshell.Wayland
import QtQuick
import "modules"
import "services"

Scope {
  id: root

  property var menuState: null

  Theme {
    id: theme
  }

  CommandRunner {
    id: commands
  }

  CompactState {
    id: compactState
  }

  SystemMonitor {
    id: systemMonitor
  }

  Variants {
    model: Quickshell.screens

    PanelWindow {
      id: panel

      required property var modelData
      readonly property bool portrait: Number(modelData.width || 0) > 0 && Number(modelData.height || 0) > Number(modelData.width || 0)
      readonly property bool narrow: !portrait && width > 0 && width <= 1600
      readonly property bool dense: compactState.compact
      readonly property int barHeight: dense ? 24 : 32
      readonly property int shadowExtent: 8
      readonly property int edgeMargin: dense ? 4 : 8
      readonly property int clusterSpacing: narrow ? 3 : dense ? 4 : 8
      readonly property int narrowTextLength: 12

      screen: modelData
      color: "transparent"
      implicitHeight: barHeight + shadowExtent
      exclusiveZone: barHeight
      exclusionMode: ExclusionMode.Normal
      WlrLayershell.namespace: "lacuna"
      WlrLayershell.layer: WlrLayer.Top

      anchors {
        top: true
        left: true
        right: true
      }

      TooltipHost {
        id: tooltips
        panelWindow: panel
        panelSurfaceHeight: panel.barHeight
        panelColor: theme.panel
      }

      Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: panel.barHeight
        color: theme.panel

        Rectangle {
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.top: parent.bottom
          height: panel.shadowExtent
          visible: !tooltips.tooltipVisible
          gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.rgba(0, 0, 0, 0.28) }
            GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.0) }
          }
        }

        Row {
          id: leftCluster
          visible: !panel.portrait
          anchors.left: parent.left
          anchors.leftMargin: panel.edgeMargin
          anchors.verticalCenter: parent.verticalCenter
          spacing: panel.clusterSpacing

          Row {
            id: navGroup
            anchors.verticalCenter: parent.verticalCenter
            spacing: panel.dense ? 0 : 2

            LacunaButton {
              text: "󱥸"
              minButtonWidth: panel.dense ? 24 : 32
              contentHorizontalPadding: 0
              accent: theme.color("color14")
              foreground: theme.foreground
              background: theme.background
              compact: panel.dense
              onTriggered: root.menuState ? root.menuState.toggle() : commands.run("omarchy menu")
            }

            Workspaces {
              foreground: theme.foreground
              background: theme.background
              accent: theme.color("color14")
              occupiedColor: theme.color("color10")
              emptyColor: theme.muted
              urgentColor: theme.color("color9")
              compact: panel.dense
              commandRunner: commands
            }
          }

          ScriptPill {
            visible: cssClass !== "hidden" && displayText.length > 0
            tooltipHost: tooltips
            compact: panel.dense
            script: "scripts/codex-weekly-status.sh"
            interval: 300000
            moduleAccent: theme.color("color5")
            image: "assets/openai-light-themed.svg"
            refreshKey: theme.rawColor("color5")
            leadingImageSize: panel.dense ? 10 : 12
            maxTextLength: panel.narrow ? panel.narrowTextLength : 32
          }

          ScriptPill {
            visible: cssClass !== "hidden" && displayText.length > 0
            tooltipHost: tooltips
            compact: panel.dense
            script: "scripts/claude-code-status.sh"
            interval: 30000
            moduleAccent: theme.color("color9")
            image: "assets/claude-ai-themed.svg"
            refreshKey: theme.rawColor("color9")
            leadingImageSize: panel.dense ? 10 : 12
            maxTextLength: panel.narrow ? panel.narrowTextLength : 32
          }

          MprisPill {
            visible: !panel.narrow
            tooltipHost: tooltips
            compact: panel.dense
            moduleAccent: theme.soft
            foreground: theme.foreground
            background: theme.background
            maxTextLength: panel.narrow ? 18 : panel.dense ? 22 : 34
            sweepOnPlaying: true
          }
        }

        Row {
          id: centerCluster
          visible: !panel.portrait
          anchors.centerIn: parent
          spacing: panel.clusterSpacing

          ScriptPill {
            tooltipHost: tooltips
            compact: panel.dense
            script: "scripts/voxtype-status.sh"
            interval: 2000
            moduleAccent: theme.color("color9")
            alertAccent: theme.color("color11")
            foreground: theme.foreground
            background: theme.background
            maxTextLength: panel.narrow ? panel.narrowTextLength : 32
            onTriggered: commands.run("omarchy voxtype model")
            onSecondaryTriggered: commands.run("omarchy voxtype config")
          }

          LacunaGlyph {
            text: "·"
            glyphColor: theme.muted
            tooltipHost: tooltips
          }

          ClockPill {
            tooltipHost: tooltips
            compact: panel.dense
            moduleAccent: theme.color("color6")
            foreground: theme.foreground
            background: theme.background
            wide: !panel.narrow
          }

          ScriptPill {
            tooltipHost: tooltips
            compact: panel.dense
            script: "scripts/weather-openmeteo.sh"
            interval: 900000
            moduleAccent: theme.color("color4")
            alertAccent: theme.color("color9")
            foreground: theme.foreground
            background: theme.background
            maxTextLength: panel.narrow ? panel.narrowTextLength : 32
            onTriggered: commands.run(scriptPath + " --open")
          }

          ScriptPill {
            tooltipHost: tooltips
            compact: panel.dense
            script: "scripts/update-status.sh"
            interval: 21600000
            moduleAccent: theme.muted
            foreground: theme.foreground
            background: theme.background
            maxTextLength: panel.narrow ? panel.narrowTextLength : 32
            onTriggered: commands.run("omarchy launch floating terminal with presentation 'omarchy update'")
          }

          ScriptPill {
            tooltipHost: tooltips
            compact: panel.dense
            script: "scripts/idle-status.sh"
            interval: 3000
            moduleAccent: theme.color("color11")
            alertAccent: theme.color("color9")
            foreground: theme.foreground
            background: theme.background
            maxTextLength: panel.narrow ? panel.narrowTextLength : 32
            onTriggered: commands.run("omarchy toggle idle")
          }

          ScriptPill {
            tooltipHost: tooltips
            compact: panel.dense
            script: "scripts/screenrecording-status.sh"
            interval: 3000
            moduleAccent: theme.color("color9")
            alertAccent: theme.color("color9")
            foreground: theme.foreground
            background: theme.background
            maxTextLength: panel.narrow ? panel.narrowTextLength : 32
            onTriggered: commands.run("omarchy capture screenrecording")
          }

          LacunaGlyph {
            text: "·"
            glyphColor: theme.muted
            tooltipHost: tooltips
          }
        }

        Row {
          id: rightCluster
          visible: !panel.portrait
          anchors.right: parent.right
          anchors.rightMargin: panel.edgeMargin
          anchors.verticalCenter: parent.verticalCenter
          spacing: panel.clusterSpacing

          Tray {
            foreground: theme.foreground
            background: theme.background
            accent: theme.color("color14")
            compact: panel.dense
            panelWindow: panel
            tooltipHost: tooltips
          }

          ThemePill {
            visible: themeService.themeTitle.length > 0
            tooltipHost: tooltips
            compact: panel.dense
            themeService: theme
            moduleAccent: theme.soft
            foreground: theme.foreground
            background: theme.background
            maxTextLength: panel.narrow ? 14 : 26
            onTriggered: commands.run("omarchy theme switcher")
            onSecondaryTriggered: commands.run("current=\"$(omarchy theme current)\"; next=\"$(omarchy theme list | grep -Fvx \"$current\" | shuf -n 1)\"; [ -n \"$next\" ] && omarchy theme set \"$next\"")
          }

          WallpaperPill {
            visible: text.length > 0
            tooltipHost: tooltips
            compact: panel.dense
            moduleAccent: theme.color("color11")
            foreground: theme.foreground
            background: theme.background
            maxTextLength: panel.narrow ? 12 : 18
            onTriggered: commands.run("omarchy theme bg-switcher")
            onSecondaryTriggered: commands.run("omarchy theme bg next")
          }

          Row {
            id: rightStatusGroup
            anchors.verticalCenter: parent.verticalCenter
            spacing: panel.narrow ? 2 : 4

            Row {
              id: rightIconStatusGroup
              anchors.verticalCenter: parent.verticalCenter
              spacing: panel.narrow ? 1 : 4

              ScriptPill {
                tooltipHost: tooltips
                compact: panel.dense
                script: "scripts/bluetooth-status.sh"
                interval: 5000
                moduleAccent: theme.color("color12")
                foreground: theme.foreground
                background: theme.background
                onTriggered: commands.run("hyprctl dispatch 'hl.dsp.exec_cmd([[omarchy launch bluetooth]])'")
              }

              ScriptPill {
                tooltipHost: tooltips
                compact: panel.dense
                script: "scripts/network-status.sh"
                interval: 3000
                moduleAccent: theme.color("color12")
                foreground: theme.foreground
                background: theme.background
                onTriggered: commands.run("hyprctl dispatch 'hl.dsp.exec_cmd([[omarchy launch wifi]])'")
              }

              ScriptPill {
                tooltipHost: tooltips
                compact: panel.dense
                script: "scripts/power-profile-status.sh"
                interval: 5000
                moduleAccent: theme.color("color6")
                foreground: theme.foreground
                background: theme.background
                onTriggered: commands.run("omarchy menu power")
              }

              BatteryPill {
                tooltipHost: tooltips
                compact: panel.dense
                moduleAccent: theme.color("color6")
                alertAccent: theme.color("color9")
                foreground: theme.foreground
                background: theme.background
                commandRunner: commands
              }
            }

            Row {
              id: rightTextStatusGroup
              anchors.verticalCenter: parent.verticalCenter
              spacing: panel.narrow ? 2 : 4

              AudioPill {
                tooltipHost: tooltips
                compact: panel.dense
                moduleAccent: theme.color("color13")
                foreground: theme.foreground
                background: theme.background
                commandRunner: commands
              }

              SystemStats {
                visible: !panel.narrow
                foreground: theme.foreground
                background: theme.background
                diskAccent: theme.color("color9")
                memoryAccent: theme.color("color10")
                cpuAccent: theme.color("color14")
                compact: panel.dense
                commandRunner: commands
                monitor: systemMonitor
                tooltipHost: tooltips
              }

              TemperaturePill {
                visible: !panel.narrow && text.length > 0
                tooltipHost: tooltips
                compact: panel.dense
                monitor: systemMonitor
                moduleAccent: theme.color("color11")
                foreground: theme.foreground
                background: theme.background
                onTriggered: commands.run("omarchy launch or focus tui btop")
              }
            }
          }

          CompactPill {
            tooltipHost: tooltips
            compact: panel.dense
            stateController: compactState
            moduleAccent: theme.color("color9")
            foreground: theme.foreground
            background: theme.background
          }
        }

        Row {
          id: portraitCenterCluster
          visible: panel.portrait
          anchors.centerIn: parent
          spacing: compactState.compact ? 3 : 6
          z: 2

          ScriptPill {
            tooltipHost: tooltips
            compact: compactState.compact
            script: "scripts/voxtype-status.sh"
            interval: 2000
            moduleAccent: theme.color("color9")
            alertAccent: theme.color("color11")
            foreground: theme.foreground
            background: theme.background
            maxTextLength: 12
            onTriggered: commands.run("omarchy voxtype model")
            onSecondaryTriggered: commands.run("omarchy voxtype config")
          }

          LacunaGlyph {
            text: "·"
            glyphColor: theme.muted
            tooltipHost: tooltips
          }

          ClockPill {
            tooltipHost: tooltips
            compact: compactState.compact
            shortMode: true
            moduleAccent: theme.color("color6")
            foreground: theme.foreground
            background: theme.background
          }

          ScriptPill {
            tooltipHost: tooltips
            compact: compactState.compact
            script: "scripts/weather-openmeteo.sh"
            interval: 900000
            moduleAccent: theme.color("color4")
            alertAccent: theme.color("color9")
            foreground: theme.foreground
            background: theme.background
            maxTextLength: 14
            onTriggered: commands.run(scriptPath + " --open")
          }

          ScriptPill {
            tooltipHost: tooltips
            compact: compactState.compact
            script: "scripts/update-status.sh"
            interval: 21600000
            moduleAccent: theme.muted
            foreground: theme.foreground
            background: theme.background
            maxTextLength: 10
            onTriggered: commands.run("omarchy launch floating terminal with presentation 'omarchy update'")
          }

          ScriptPill {
            tooltipHost: tooltips
            compact: compactState.compact
            script: "scripts/idle-status.sh"
            interval: 3000
            moduleAccent: theme.color("color11")
            alertAccent: theme.color("color9")
            foreground: theme.foreground
            background: theme.background
            maxTextLength: 10
            onTriggered: commands.run("omarchy toggle idle")
          }

          ScriptPill {
            tooltipHost: tooltips
            compact: compactState.compact
            script: "scripts/screenrecording-status.sh"
            interval: 3000
            moduleAccent: theme.color("color9")
            alertAccent: theme.color("color9")
            foreground: theme.foreground
            background: theme.background
            maxTextLength: 10
            onTriggered: commands.run("omarchy capture screenrecording")
          }
        }

        Item {
          id: portraitLeftCluster
          visible: panel.portrait
          anchors.left: parent.left
          anchors.leftMargin: panel.edgeMargin
          anchors.right: portraitCenterCluster.left
          anchors.rightMargin: compactState.compact ? 8 : 12
          anchors.top: parent.top
          anchors.bottom: parent.bottom
          clip: true

          Row {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: compactState.compact ? 3 : 6

            Row {
              anchors.verticalCenter: parent.verticalCenter
              spacing: compactState.compact ? 0 : 2

              LacunaButton {
                text: "󱥸"
                minButtonWidth: compactState.compact ? 24 : 32
                contentHorizontalPadding: 0
                accent: theme.color("color14")
                foreground: theme.foreground
                background: theme.background
                compact: compactState.compact
                onTriggered: root.menuState ? root.menuState.toggle() : commands.run("omarchy menu")
              }

              Workspaces {
                foreground: theme.foreground
                background: theme.background
                accent: theme.color("color14")
                occupiedColor: theme.color("color10")
                emptyColor: theme.muted
                urgentColor: theme.color("color9")
                compact: compactState.compact
                commandRunner: commands
              }
            }

            MprisPill {
              tooltipHost: tooltips
              compact: compactState.compact
              moduleAccent: theme.soft
              foreground: theme.foreground
              background: theme.background
              maxTextLength: 20
              sweepOnPlaying: true
            }
          }
        }

        Row {
          id: portraitRightCluster
          visible: panel.portrait
          anchors.right: parent.right
          anchors.rightMargin: panel.edgeMargin
          anchors.verticalCenter: parent.verticalCenter
          spacing: compactState.compact ? 2 : 5

          Tray {
            foreground: theme.foreground
            background: theme.background
            accent: theme.color("color14")
            compact: compactState.compact
            panelWindow: panel
            tooltipHost: tooltips
          }

          ScriptPill {
            tooltipHost: tooltips
            compact: compactState.compact
            script: "scripts/bluetooth-status.sh"
            interval: 5000
            moduleAccent: theme.color("color12")
            foreground: theme.foreground
            background: theme.background
            onTriggered: commands.run("hyprctl dispatch 'hl.dsp.exec_cmd([[omarchy launch bluetooth]])'")
          }

          ScriptPill {
            tooltipHost: tooltips
            compact: compactState.compact
            script: "scripts/network-status.sh"
            interval: 3000
            moduleAccent: theme.color("color12")
            foreground: theme.foreground
            background: theme.background
            onTriggered: commands.run("hyprctl dispatch 'hl.dsp.exec_cmd([[omarchy launch wifi]])'")
          }

          ScriptPill {
            tooltipHost: tooltips
            compact: compactState.compact
            script: "scripts/power-profile-status.sh"
            interval: 5000
            moduleAccent: theme.color("color6")
            foreground: theme.foreground
            background: theme.background
            onTriggered: commands.run("omarchy menu power")
          }

          BatteryPill {
            tooltipHost: tooltips
            compact: compactState.compact
            moduleAccent: theme.color("color6")
            alertAccent: theme.color("color9")
            foreground: theme.foreground
            background: theme.background
            commandRunner: commands
          }

          AudioPill {
            tooltipHost: tooltips
            compact: compactState.compact
            moduleAccent: theme.color("color13")
            foreground: theme.foreground
            background: theme.background
            commandRunner: commands
          }

          CompactPill {
            tooltipHost: tooltips
            compact: compactState.compact
            stateController: compactState
            moduleAccent: theme.color("color9")
            foreground: theme.foreground
            background: theme.background
          }
        }

      }
    }

  }

  Variants {
    model: Quickshell.screens

    PanelWindow {
      id: bottomPanel

      required property var modelData
      readonly property bool portrait: Number(modelData.width || 0) > 0 && Number(modelData.height || 0) > Number(modelData.width || 0)
      readonly property int barHeight: compactState.compact ? 24 : 32
      readonly property int shadowExtent: 8
      readonly property int edgeMargin: compactState.compact ? 4 : 8

      screen: modelData
      visible: portrait
      color: "transparent"
      implicitHeight: barHeight + shadowExtent
      exclusiveZone: visible ? barHeight : 0
      exclusionMode: ExclusionMode.Normal
      WlrLayershell.namespace: "lacuna-bottom"
      WlrLayershell.layer: WlrLayer.Top

      anchors {
        bottom: true
        left: true
        right: true
      }

      TooltipHost {
        id: bottomTooltips
        panelWindow: bottomPanel
        panelSurfaceY: bottomPanel.shadowExtent
        panelSurfaceHeight: bottomPanel.barHeight
        panelColor: theme.panel
      }

      Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: bottomPanel.barHeight
        color: theme.panel

        Rectangle {
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.bottom: parent.top
          height: bottomPanel.shadowExtent
          visible: !bottomTooltips.tooltipVisible
          gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.rgba(0, 0, 0, 0.0) }
            GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.28) }
          }
        }

        Row {
          anchors.left: parent.left
          anchors.leftMargin: bottomPanel.edgeMargin
          anchors.verticalCenter: parent.verticalCenter
          spacing: compactState.compact ? 3 : 6

          ScriptPill {
            tooltipHost: bottomTooltips
            compact: compactState.compact
            script: "scripts/codex-weekly-status.sh"
            interval: 300000
            moduleAccent: theme.color("color5")
            image: "assets/openai-light-themed.svg"
            refreshKey: theme.rawColor("color5")
            leadingImageSize: compactState.compact ? 10 : 12
            maxTextLength: 18
          }

          ScriptPill {
            tooltipHost: bottomTooltips
            compact: compactState.compact
            script: "scripts/claude-code-status.sh"
            interval: 30000
            moduleAccent: theme.color("color9")
            image: "assets/claude-ai-themed.svg"
            refreshKey: theme.rawColor("color9")
            leadingImageSize: compactState.compact ? 10 : 12
            maxTextLength: 18
          }
        }

        Row {
          anchors.centerIn: parent
          spacing: compactState.compact ? 3 : 6

          SystemStats {
            foreground: theme.foreground
            background: theme.background
            diskAccent: theme.color("color9")
            memoryAccent: theme.color("color10")
            cpuAccent: theme.color("color14")
            compact: compactState.compact
            commandRunner: commands
            monitor: systemMonitor
            tooltipHost: bottomTooltips
          }

          TemperaturePill {
            tooltipHost: bottomTooltips
            compact: compactState.compact
            monitor: systemMonitor
            moduleAccent: theme.color("color11")
            foreground: theme.foreground
            background: theme.background
            maxTextLength: 10
            onTriggered: commands.run("omarchy launch or focus tui btop")
          }
        }

        Row {
          anchors.right: parent.right
          anchors.rightMargin: bottomPanel.edgeMargin
          anchors.verticalCenter: parent.verticalCenter
          spacing: compactState.compact ? 3 : 6

          ThemePill {
            tooltipHost: bottomTooltips
            compact: compactState.compact
            themeService: theme
            moduleAccent: theme.soft
            foreground: theme.foreground
            background: theme.background
            maxTextLength: 26
            onTriggered: commands.run("omarchy theme switcher")
            onSecondaryTriggered: commands.run("current=\"$(omarchy theme current)\"; next=\"$(omarchy theme list | grep -Fvx \"$current\" | shuf -n 1)\"; [ -n \"$next\" ] && omarchy theme set \"$next\"")
          }

          WallpaperPill {
            tooltipHost: bottomTooltips
            compact: compactState.compact
            moduleAccent: theme.color("color11")
            foreground: theme.foreground
            background: theme.background
            maxTextLength: 18
            onTriggered: commands.run("omarchy theme bg-switcher")
            onSecondaryTriggered: commands.run("omarchy theme bg next")
          }
        }
      }
    }
  }
}
