import Cocoa
import Defaults
import Settings
import SwiftUI

@main
class AppDelegate: NSObject, NSApplicationDelegate {
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
      return // Exit early if running in preview
    }
    #endif

    userState = UserState()
    controller = Controller(userState: userState)
    statusItem = StatusItem()

    statusItem.handlePreferences = {
      self.settingsWindowController.show()
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

    settingsWindowController.show()

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
    let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
    let accessibilityEnabled = AXIsProcessTrustedWithOptions(options)

    if accessibilityEnabled {
      startListeningForMouseEvents()
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
