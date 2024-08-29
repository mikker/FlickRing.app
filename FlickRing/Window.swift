import Cocoa
import QuartzCore
import SwiftUI

class Window: NSPanel, NSWindowDelegate {
    override var acceptsFirstResponder: Bool { return true }
    override var canBecomeKey: Bool { return true }
    override var canBecomeMain: Bool { return true }

    var controller: Controller

    init(controller: Controller) {
        self.controller = controller

        super.init(
            contentRect: NSRect(x: 0, y: 0, width: MainView.size, height: MainView.size),
            styleMask: [.nonactivatingPanel],
            backing: .buffered, defer: false
        )

        isFloatingPanel = true
        isReleasedWhenClosed = false
        animationBehavior = .none

        let view = MainView(userState: self.controller.userState)
        contentView = NSHostingView(rootView: view)

        backgroundColor = .clear
        isOpaque = false

        delegate = self
    }

    func windowWillClose(_: Notification) {}

    override func makeKeyAndOrderFront(_ sender: Any?) {
        super.makeKeyAndOrderFront(sender)
    }

    func show() {
        centerBelowCursor()
        makeKeyAndOrderFront(nil)
        fadeInAndUp()
    }

    func hide(afterClose: (() -> Void)? = nil) {
        fadeOutAndDown {
            self.close()
            afterClose?()
        }
    }

    func centerBelowCursor() {
        let mouseLocation = NSEvent.mouseLocation
        let windowSize = self.frame.size
        let windowOrigin = NSPoint(
            x: mouseLocation.x - windowSize.width / 2,
            y: mouseLocation.y - windowSize.height / 2
        )
        
        self.setFrameOrigin(windowOrigin)
    }
}
