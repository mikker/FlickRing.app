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
      styleMask: [.borderless, .nonactivatingPanel],
      backing: .buffered, defer: false
    )

    isReleasedWhenClosed = false
    animationBehavior = .none
    isOpaque = false
    backgroundColor = .clear
    isMovableByWindowBackground = false
    level = .statusBar + 1

    let view = MainView(userState: self.controller.userState)
    contentView = NSHostingView(rootView: view)

    delegate = self
  }

  func windowWillClose(_: Notification) {}

  override func makeKeyAndOrderFront(_ sender: Any?) {
    super.makeKeyAndOrderFront(sender)
    //        NSApp.activate(ignoringOtherApps: true)
  }

  func show(after: (() -> Void)?) {
    centerBelowCursor()
    makeKeyAndOrderFront(nil)
    fadeIn {
      after?()
    }
  }

  func hide(after: (() -> Void)?) {
    fadeOut {
      self.close()
      after?()
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

  override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect {
    return frameRect
  }
}
