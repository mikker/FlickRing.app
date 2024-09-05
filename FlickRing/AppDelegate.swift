import Cocoa
import Defaults
import Settings
import Sparkle
import SwiftUI

@main
class AppDelegate: NSObject, NSApplicationDelegate, SPUStandardUserDriverDelegate {
  @IBOutlet var updateController: SPUStandardUpdaterController!

  var statusItem: StatusItem!
  var controller: Controller!
  var userState: UserState!

  lazy var settingsWindowController = SettingsWindowController(
    panes: [
      Settings.Pane(
        identifier: .general, title: "General",
        toolbarIcon: NSImage(named: NSImage.preferencesGeneralName)!,
        contentView: { GeneralPane() }
      )
    ]
  )

  func applicationDidFinishLaunching(_ aNotification: Notification) {
    // Check if running in preview mode
    #if DEBUG
      if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" {
        return  // Exit early if running in preview
      }
    #endif

    userState = UserState()
    controller = Controller(userState: userState)
    statusItem = StatusItem()

    statusItem.handlePreferences = {
      self.settingsWindowController.show()
    }
    statusItem.handleUpdates = {
      self.updateController.checkForUpdates(nil)
    }

    statusItem.enable()

    if AXIsProcessTrusted() {
      startListeningForMouseEvents()
    } else {
      requestAccessibilityPermission()
    }

    if Defaults[.showPreferencesOnLaunch] {
      settingsWindowController.show()
    }

    NotificationCenter.default.addObserver(
      self,
      selector: #selector(handleConfigurationStateChange),
      name: .configurationStateChanged,
      object: nil
    )
  }

  func startListeningForMouseEvents() {
    controller.startListeningForMouseEvents()
  }

  func requestAccessibilityPermission() {
    let promptKey = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
    let opts = [promptKey: true] as CFDictionary
    let accessibilityEnabled = AXIsProcessTrustedWithOptions(opts)

    if accessibilityEnabled {
      startListeningForMouseEvents()
    } else {
      showAlertForAccessibilityPermission()
    }
  }

  func showAlertForAccessibilityPermission() {
    let alert = NSAlert()
    alert.messageText = "Accessibility Permission Required"
    alert.informativeText = "Please enable accessibility permissions in System Preferences."
    alert.alertStyle = .warning
    alert.addButton(withTitle: "OK")
    alert.addButton(withTitle: "Open System Preferences")

    let response = alert.runModal()
    if response == .alertSecondButtonReturn {
      openSystemPreferences()
    }
  }

  func openSystemPreferences() {
    if let url = URL(
      string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
    {
      NSWorkspace.shared.open(url)
    }
  }

  @IBAction
  func settingsMenuItemActionHandler(_: NSMenuItem) {
    settingsWindowController.show()
  }

  @objc func handleConfigurationStateChange(_ notification: Notification) {
    if let isConfiguring = notification.object as? Bool {
      controller.setConfiguring(isConfiguring)
    }
  }

  // MARK: SPUStandardUserDriverDelegate

  var supportsGentleScheduledUpdateReminders: Bool = true
}

extension Notification.Name {
  static let mouseButtonSelected = Notification.Name("mouseButtonSelected")
  static let configurationStateChanged = Notification.Name("configurationStateChanged")
}
