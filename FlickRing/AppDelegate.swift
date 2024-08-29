import Cocoa
import Settings
import Defaults
import SwiftUI

@main
class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: StatusItem!
    var controller: Controller!
    var userState: UserState!
    private var mouseListener: MouseListener?

    lazy var settingsWindowController = SettingsWindowController(
        panes: [
            Settings.Pane(
                identifier: .general, title: "General",
                toolbarIcon: NSImage(named: NSImage.preferencesGeneralName)!,
                contentView: { GeneralPane() }
            ),
        ]
    )

    func applicationDidFinishLaunching(_ aNotification: Notification) {
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
    }

    func startListeningForMouseEvents() {
        mouseListener?.startListening()
    }

    func handleMouseEvent(type: CGEventType, event: CGEvent) {
        if event.getIntegerValueField(.mouseEventButtonNumber) == userState.selectedMouseButton {
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
}

extension Notification.Name {
    static let startListeningForMouseButton = Notification.Name("startListeningForMouseButton")
    static let mouseButtonSelected = Notification.Name("mouseButtonSelected")
}
