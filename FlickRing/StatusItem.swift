import Cocoa

class StatusItem {
  var statusItem: NSStatusItem?

  var handlePreferences: (() -> Void)?
  var handleUpdates: (() -> Void)?

  func enable() {
    statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

    guard let item = statusItem else {
      print("No status item")
      return
    }

    if let menubarButton = item.button {
      menubarButton.image = NSImage(named: NSImage.Name("StatusItem"))
    }

    let menu = NSMenu()

    let preferencesItem = NSMenuItem(
      title: "Preferences…", action: #selector(showPreferences), keyEquivalent: ","
    )
    preferencesItem.target = self
    menu.addItem(preferencesItem)

    let updatesItem = NSMenuItem(
      title: "Check for updates", action: #selector(checkForUpdates), keyEquivalent: ""
    )
    updatesItem.target = self
    menu.addItem(updatesItem)

    menu.addItem(NSMenuItem.separator())

    menu.addItem(
      NSMenuItem(
        title: "Quit Flick Ring", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"
      ))

    item.menu = menu
  }

  @objc func showPreferences() {
    handlePreferences?()
  }

  @objc func checkForUpdates() {
    handleUpdates?()
  }
}
