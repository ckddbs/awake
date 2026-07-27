import AppKit
import Foundation
import ServiceManagement

private enum Amp12 {
  static let appName = "Awake"
  static let defaultDuration: TimeInterval = 43_200
  static let durationDefaultsKey = "durationSeconds"
  static let stateDirectory = FileManager.default.homeDirectoryForCurrentUser
    .appendingPathComponent("Library/Application Support/KeepAwake12h", isDirectory: true)
  static let pidFile = stateDirectory.appendingPathComponent("caffeinate.pid")
  static let endFile = stateDirectory.appendingPathComponent("end_epoch")
  static let durationFile = stateDirectory.appendingPathComponent("duration_seconds")
  static let durationOptions: [(label: String, seconds: TimeInterval)] = [
    ("30 min", 1_800),
    ("1 hour", 3_600),
    ("3 hours", 10_800),
    ("6 hours", 21_600),
    ("12 hours", 43_200),
    ("24 hours", 86_400)
  ]
}

final class AppDelegate: NSObject, NSApplicationDelegate {
  private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
  private let menu = NSMenu()
  private let toggleItem = NSMenuItem(title: "Turn On", action: #selector(toggle), keyEquivalent: "")
  private let startItem = NSMenuItem(title: "Start", action: #selector(start), keyEquivalent: "")
  private let stopItem = NSMenuItem(title: "Stop", action: #selector(stop), keyEquivalent: "")
  private let statusItemText = NSMenuItem(title: "Status: Off", action: nil, keyEquivalent: "")
  private let durationMenu = NSMenu(title: "Duration")
  private let openAtLoginItem = NSMenuItem(title: "Open at Login", action: #selector(toggleOpenAtLogin), keyEquivalent: "")
  private var timer: Timer?

  func applicationDidFinishLaunching(_ notification: Notification) {
    NSApp.setActivationPolicy(.accessory)
    ensureOpenAtLogin()
    configureMenu()
    configureStatusButton()
    refreshStatus()

    timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
      self?.refreshStatus()
    }
  }

  private func configureStatusButton() {
    guard let button = statusItem.button else {
      return
    }

    button.target = self
    button.action = #selector(statusItemClicked)
    button.sendAction(on: [.leftMouseUp, .rightMouseUp])
    button.imagePosition = .imageLeft
  }

  private func configureMenu() {
    toggleItem.target = self
    startItem.target = self
    stopItem.target = self
    openAtLoginItem.target = self

    let durationParent = NSMenuItem(title: "Duration", action: nil, keyEquivalent: "")
    durationParent.submenu = durationMenu
    configureDurationMenu()

    menu.addItem(statusItemText)
    menu.addItem(.separator())
    menu.addItem(toggleItem)
    menu.addItem(startItem)
    menu.addItem(stopItem)
    menu.addItem(.separator())
    menu.addItem(durationParent)
    menu.addItem(withTitle: "Refresh", action: #selector(refresh), keyEquivalent: "").target = self
    menu.addItem(openAtLoginItem)
    menu.addItem(.separator())
    menu.addItem(withTitle: "Quit", action: #selector(quit), keyEquivalent: "q").target = self
  }

  private func configureDurationMenu() {
    durationMenu.removeAllItems()

    for option in Amp12.durationOptions {
      let item = NSMenuItem(title: option.label, action: #selector(selectDuration(_:)), keyEquivalent: "")
      item.target = self
      item.representedObject = option.seconds
      durationMenu.addItem(item)
    }
  }

  @objc private func statusItemClicked() {
    guard let event = NSApp.currentEvent else {
      toggle()
      return
    }

    if event.type == .rightMouseUp || event.modifierFlags.contains(.control) {
      statusItem.popUpMenu(menu)
      return
    }

    toggle()
  }

  @objc private func toggle() {
    if isRunning() {
      stop()
    } else {
      start()
    }
  }

  @objc private func start() {
    stopProcessOnly()
    try? FileManager.default.createDirectory(at: Amp12.stateDirectory, withIntermediateDirectories: true)

    let duration = selectedDuration()
    let endEpoch = Int(Date().addingTimeInterval(duration).timeIntervalSince1970)
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/caffeinate")
    process.arguments = ["-i", "-s", "-t", String(Int(duration))]

    do {
      try process.run()
      try String(process.processIdentifier).write(to: Amp12.pidFile, atomically: true, encoding: .utf8)
      try String(endEpoch).write(to: Amp12.endFile, atomically: true, encoding: .utf8)
      try String(Int(duration)).write(to: Amp12.durationFile, atomically: true, encoding: .utf8)
      notify("On for \(durationLabel(duration)). Ends at \(timeString(epoch: endEpoch))")
    } catch {
      notify("Failed to start: \(error.localizedDescription)")
    }

    refreshStatus()
  }

  @objc private func stop() {
    let remainingText = remainingStatus()?.text ?? "unknown"
    stopProcessOnly()
    removeStateFiles()
    notify("Off. Was remaining: \(remainingText)")
    refreshStatus()
  }

  @objc private func refresh() {
    refreshStatus()
  }

  @objc private func selectDuration(_ sender: NSMenuItem) {
    guard let seconds = sender.representedObject as? TimeInterval else {
      return
    }

    UserDefaults.standard.set(seconds, forKey: Amp12.durationDefaultsKey)
    notify("Duration set to \(durationLabel(seconds))")
    refreshStatus()
  }

  @objc private func toggleOpenAtLogin() {
    if #available(macOS 13.0, *) {
      do {
        if SMAppService.mainApp.status == .enabled {
          try SMAppService.mainApp.unregister()
        } else {
          try SMAppService.mainApp.register()
        }
      } catch {
        notify("Login item failed: \(error.localizedDescription)")
      }
    } else {
      notify("Open at Login requires macOS 13 or later")
    }

    refreshStatus()
  }

  @objc private func quit() {
    NSApp.terminate(nil)
  }

  private func refreshStatus() {
    cleanupStaleState()
    updateDurationMenu()

    if let remaining = remainingStatus(), isRunning() {
      setStatusIcon(systemName: "bolt.fill", title: " \(remaining.compactText)")
      statusItemText.title = "On: \(remaining.text), ends at \(remaining.endsAt)"
      toggleItem.title = "Turn Off"
      startItem.isEnabled = false
      stopItem.isEnabled = true
    } else {
      setStatusIcon(systemName: "bolt.slash.fill", title: "")
      statusItemText.title = "Status: Off"
      toggleItem.title = "Turn On for \(durationLabel(selectedDuration()))"
      startItem.title = "Start \(durationLabel(selectedDuration()))"
      startItem.isEnabled = true
      stopItem.isEnabled = false
    }

    if #available(macOS 13.0, *) {
      openAtLoginItem.state = SMAppService.mainApp.status == .enabled ? .on : .off
    }
  }

  private func setStatusIcon(systemName: String, title: String) {
    guard let button = statusItem.button else {
      return
    }

    let image = NSImage(systemSymbolName: systemName, accessibilityDescription: nil)
    image?.isTemplate = true
    button.image = image
    button.title = title
  }

  private func updateDurationMenu() {
    let duration = selectedDuration()

    for item in durationMenu.items {
      guard let seconds = item.representedObject as? TimeInterval else {
        continue
      }

      item.state = Int(seconds) == Int(duration) ? .on : .off
    }
  }

  private func ensureOpenAtLogin() {
    guard #available(macOS 13.0, *) else {
      return
    }

    do {
      if SMAppService.mainApp.status == .enabled {
        try SMAppService.mainApp.unregister()
      }

      try SMAppService.mainApp.register()
    } catch {
      notify("Login item failed: \(error.localizedDescription)")
    }
  }

  private func selectedDuration() -> TimeInterval {
    let stored = UserDefaults.standard.double(forKey: Amp12.durationDefaultsKey)
    return stored > 0 ? stored : Amp12.defaultDuration
  }

  private func isRunning() -> Bool {
    guard let pid = currentPid() else {
      return false
    }

    return kill(pid, 0) == 0
  }

  private func currentPid() -> pid_t? {
    guard let pidText = try? String(contentsOf: Amp12.pidFile, encoding: .utf8)
      .trimmingCharacters(in: .whitespacesAndNewlines),
      let pid = Int32(pidText) else {
      return nil
    }

    return pid
  }

  private func stopProcessOnly() {
    guard let pid = currentPid(), kill(pid, 0) == 0 else {
      return
    }

    kill(pid, SIGTERM)
  }

  private func removeStateFiles() {
    try? FileManager.default.removeItem(at: Amp12.pidFile)
    try? FileManager.default.removeItem(at: Amp12.endFile)
    try? FileManager.default.removeItem(at: Amp12.durationFile)
  }

  private func cleanupStaleState() {
    if let endEpoch = endEpoch(), endEpoch <= Int(Date().timeIntervalSince1970) {
      stopProcessOnly()
      removeStateFiles()
      return
    }

    if FileManager.default.fileExists(atPath: Amp12.pidFile.path), !isRunning() {
      removeStateFiles()
    }
  }

  private func remainingStatus() -> (text: String, compactText: String, endsAt: String)? {
    guard let endEpoch = endEpoch() else {
      return nil
    }

    let remaining = endEpoch - Int(Date().timeIntervalSince1970)
    guard remaining > 0 else {
      return nil
    }

    let hours = remaining / 3600
    let minutes = (remaining % 3600) / 60
    let text = String(format: "%dh %02dm", hours, minutes)
    let compactText = hours > 0 ? "\(hours)h" : "\(minutes)m"
    return (text, compactText, timeString(epoch: endEpoch))
  }

  private func endEpoch() -> Int? {
    guard let endText = try? String(contentsOf: Amp12.endFile, encoding: .utf8)
      .trimmingCharacters(in: .whitespacesAndNewlines),
      let endEpoch = Int(endText) else {
      return nil
    }

    return endEpoch
  }

  private func durationLabel(_ duration: TimeInterval) -> String {
    let seconds = Int(duration)
    if seconds % 3600 == 0 {
      return "\(seconds / 3600)h"
    }

    return "\(seconds / 60)m"
  }

  private func timeString(epoch: Int) -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "HH:mm"
    return formatter.string(from: Date(timeIntervalSince1970: TimeInterval(epoch)))
  }

  private func notify(_ message: String) {
    let notification = NSUserNotification()
    notification.title = Amp12.appName
    notification.informativeText = message
    NSUserNotificationCenter.default.deliver(notification)
  }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
