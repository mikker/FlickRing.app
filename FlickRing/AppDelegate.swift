import Cocoa
import Defaults
import Settings
import Sparkle
import SwiftUI

@main
class AppDelegate: NSObject, NSApplicationDelegate {
  @IBOutlet var updateController: SPUStandardUpdaterController!

  var statusItem: StatusItem!
  var controller: Controller!
  var userState: UserState!
  private var mouseListener: MouseListener?
  @objc dynamic var isConfiguring = false

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

    mouseListener = MouseListener { [weak self] type, event in
      self?.handleMouseEvent(type: type, event: event)
    }

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
    mouseListener?.startListening()
  }

  func handleMouseEvent(type: CGEventType, event: CGEvent) {
    let buttonNumber = event.getIntegerValueField(.mouseEventButtonNumber)

    if isConfiguring {
      if buttonNumber >= 2 {
        NotificationCenter.default.post(name: .mouseButtonSelected, object: buttonNumber)
      }
    } else if buttonNumber == Defaults[.selectedMouseButton] {
      if type == .otherMouseDown {
        controller.show()
      } else if type == .otherMouseUp {
        controller.hide()
      }
    }
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
      self.isConfiguring = isConfiguring
    }
  }
}

extension Notification.Name {
  static let mouseButtonSelected = Notification.Name("mouseButtonSelected")
  static let configurationStateChanged = Notification.Name("configurationStateChanged")
}
