import AppKit
import SwiftUI

@MainActor
struct StatusMenuView: View {
  let dismissMenu: () -> Void
  @ObservedObject private var appState = AppState.shared
  @ObservedObject private var pauseManager = PauseManager.shared
  private let updaterManager = UpdaterManager.shared

  private var controlMode: RecordingControlMode {
    RecordingControl.currentMode(appState: appState, pauseManager: pauseManager)
  }

  var body: some View {
    VStack(spacing: 7) {
      // Pause/Resume section
      if controlMode == .active {
        PauseSection(onPause: pauseRecording)
      } else {
        PausedSection(onResume: resumeRecording)
      }

      MenuDivider()

      MenuRow(title: "Open Dayflow", systemImage: "macwindow", action: openDayflow)
      MenuRow(title: "Open Recordings", systemImage: "folder", action: openRecordingsFolder)
      MenuRow(
        title: "Check for Updates", systemImage: "arrow.triangle.2.circlepath",
        action: checkForUpdates)

      MenuDivider()

      MenuRow(
        title: "Quit Completely",
        systemImage: "power",
        accent: .red,
        role: .destructive,
        action: quitDayflow
      )
    }
    .padding(.vertical, 10)
    .padding(.horizontal, 10)
    .frame(width: 224)
    .background(.thinMaterial)
    .overlay(
      RoundedRectangle(cornerRadius: 14, style: .continuous)
        .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.75)
    )
    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
  }

  private func pauseRecording(duration: PauseDuration) {
    pauseManager.pause(for: duration, source: .menuBar)
  }

  private func resumeRecording() {
    if pauseManager.isPaused {
      pauseManager.resume(source: .userClickedMenuBar)
    } else {
      RecordingControl.start(reason: "user_menu_bar")
    }
  }

  private func openDayflow() {
    performAfterMenuDismiss {
      let showDockIcon = UserDefaults.standard.object(forKey: "showDockIcon") as? Bool ?? true
      if showDockIcon {
        NSApp.setActivationPolicy(.regular)
      }

      NSApp.unhide(nil)
      MainWindowController.shared.showMainWindow()
      NSApp.activate(ignoringOtherApps: true)
    }
  }

  private func openRecordingsFolder() {
    performAfterMenuDismiss {
      let directory = StorageManager.shared.recordingsRoot
      NSWorkspace.shared.open(directory)
    }
  }

  private func checkForUpdates() {
    performAfterMenuDismiss {
      updaterManager.checkForUpdates(showUI: true)
      NSApp.activate(ignoringOtherApps: true)
    }
  }

  private func quitDayflow() {
    performAfterMenuDismiss {
      AppDelegate.allowTermination = true
      NSApp.terminate(nil)
    }
  }

  private func performAfterMenuDismiss(_ action: @escaping () -> Void) {
    dismissMenu()

    DispatchQueue.main.async {
      DispatchQueue.main.async {
        action()
      }
    }
  }
}

// MARK: - Pause Section (Not Paused State)

private struct PauseSection: View {
  let onPause: (PauseDuration) -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 7) {
      // Header
      Text("Pause Dayflow")
        .font(.system(size: 12, weight: .semibold))
        .foregroundStyle(.secondary)
        .padding(.horizontal, 2)

      // Duration picker
      DurationPicker(onSelect: onPause)
    }
  }
}

// MARK: - Duration Picker

private struct DurationPicker: View {
  let onSelect: (PauseDuration) -> Void

  private let options: [(label: String, duration: PauseDuration)] = [
    ("15 Min", .minutes15),
    ("30 Min", .minutes30),
    ("1 Hour", .hour1),
    ("∞", .indefinite),
  ]

  var body: some View {
    HStack(spacing: 0) {
      ForEach(Array(options.enumerated()), id: \.offset) { index, option in
        DurationOption(
          label: option.label,
          onTap: { onSelect(option.duration) }
        )

        if index < options.count - 1 {
          Divider()
            .frame(height: 16)
            .opacity(0.3)
        }
      }
    }
    .frame(height: 34)
    .background(Color.primary.opacity(0.075))
    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    .overlay(
      RoundedRectangle(cornerRadius: 8, style: .continuous)
        .strokeBorder(Color.primary.opacity(0.1), lineWidth: 0.75)
    )
  }
}

private struct DurationOption: View {
  let label: String
  let onTap: () -> Void

  @State private var isHovering = false

  var body: some View {
    Button(action: onTap) {
      Text(label)
        .font(.system(size: 12, weight: .semibold))
        .foregroundStyle(isHovering ? .white : .primary)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 6)
        .background(
          Group {
            if isHovering {
              RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(Color.accentColor)
                .padding(2)
            }
          }
        )
    }
    .frame(maxWidth: .infinity)
    .buttonStyle(.plain)
    .pointingHandCursor()
    .onHover { hovering in
      withAnimation(.easeInOut(duration: 0.15)) {
        isHovering = hovering
      }
    }
  }
}

// MARK: - Paused Section (Active Pause State)

private struct PausedSection: View {
  let onResume: () -> Void
  @ObservedObject private var pauseManager = PauseManager.shared

  var body: some View {
    VStack(spacing: 6) {
      // Countdown badge (only shown for timed pause)
      if let timeString = pauseManager.remainingTimeFormatted {
        CountdownBadge(remainingTime: timeString)
      }

      // Resume button
      MenuRow(
        title: "Resume Dayflow",
        systemImage: "play.circle",
        accent: .accentColor,
        action: onResume
      )
    }
  }
}

// MARK: - Countdown Badge

private struct CountdownBadge: View {
  let remainingTime: String

  var body: some View {
    HStack(spacing: 0) {
      Text("Dayflow paused for ")
        .font(.system(size: 11, weight: .medium))
      Text(remainingTime)
        .font(.system(size: 11, weight: .bold).monospacedDigit())
    }
    .foregroundStyle(.white)
    .padding(.horizontal, 12)
    .padding(.vertical, 6)
    .frame(maxWidth: .infinity)
    .background(Color.accentColor)
    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
  }
}

// MARK: - Menu Row

private struct MenuRow: View {
  let title: String
  var systemImage: String? = nil
  var accent: Color = .primary
  var role: RowRole = .standard
  var keepsMenuOpen: Bool = false
  var action: () -> Void

  @State private var hovering = false

  enum RowRole {
    case standard
    case destructive
  }

  var body: some View {
    Button(action: handleTap) {
      HStack(spacing: 8) {
        if let systemImage {
          Image(systemName: systemImage)
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(iconColor)
            .frame(width: 18, height: 18)
        } else {
          // Empty spacer to align text with rows that have icons
          Color.clear.frame(width: 18, height: 18)
        }

        Text(title)
          .font(.system(size: 13, weight: .medium))
          .foregroundStyle(textColor)
          .lineLimit(1)

        Spacer(minLength: 0)
      }
      .padding(.vertical, 6)
      .padding(.horizontal, 7)
      .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
      .background(
        RoundedRectangle(cornerRadius: 8, style: .continuous)
          .fill(rowBackground)
      )
    }
    .buttonStyle(.plain)
    .pointingHandCursor()
    .onHover { hovering = $0 }
  }

  private var iconColor: Color {
    role == .destructive ? accent : .secondary
  }

  private var textColor: Color {
    role == .destructive ? accent : .primary
  }

  private var rowBackground: Color {
    if hovering {
      return role == .destructive ? Color.red.opacity(0.12) : Color.primary.opacity(0.08)
    }

    return .clear
  }

  private func handleTap() {
    action()
  }
}

// MARK: - Menu Divider

private struct MenuDivider: View {
  var body: some View {
    Rectangle()
      .fill(Color.primary.opacity(0.08))
      .frame(height: 0.5)
      .padding(.horizontal, 2)
      .padding(.vertical, 3)
  }
}
