import Cocoa

class StatusItem {
    var statusItem: NSStatusItem?

    var handlePreferences: (() -> Void)?

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

        menu.addItem(NSMenuItem.separator())

        menu.addItem(
            NSMenuItem(
                title: "Quit Leader Key", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"
            ))

        item.menu = menu
    }

    @objc func showPreferences() {
        handlePreferences?()
    }
}
