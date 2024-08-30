import Cocoa
import Combine
import SwiftUI
import Defaults
import Carbon
import AppKit

class Controller {
  var window: Window!
  var userState: UserState
  private var eventMonitor: Any?

  init(userState: UserState) {
    self.userState = userState
    self.window = Window(controller: self)
  }

  func show() {
    window.show {
      self.setupEventMonitor()
    }
  }

  func hide() {
    let selectedSection = self.userState.hoveredSection
    self.commit(selectedSection)

    window.hide {
      self.userState.clear()
    }

    removeEventMonitor()

    // Cancel the original mouse event if a direction was selected
    if selectedSection != .none {
      cancelOriginalMouseEvent()
    }
  }

  private func commit(_ section: HoveredSection) {
    let action: ActionConfig
    switch section {
    case .up:
      action = Defaults[.upAction]
    case .down:
      action = Defaults[.downAction]
    case .left:
      action = Defaults[.leftAction]
    case .right:
      action = Defaults[.rightAction]
    default:
      return
    }

    executeAction(action)
  }

  private func executeAction(_ action: ActionConfig) {
    switch action.type {
    case .doNothing:
      break
    case .sendKey:
      simulateKeyEvent(action.keyEvent)
    case .pressMouseButton:
      simulateMouseClick(button: CGMouseButton(rawValue: UInt32(action.mouseButton))!)
    case .openURL:
      if let url = URL(string: action.url) {
        NSWorkspace.shared.open(url, configuration: DontActivateConfiguration.shared.configuration)
      }
    }
  }

  private func simulateKeyEvent(_ keyEvent: KeyEvent?) {
    guard let keyEvent = keyEvent else { return }
    
    let source = CGEventSource(stateID: .combinedSessionState)
    
    let keyDown = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(keyEvent.keyCode), keyDown: true)
    let keyUp = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(keyEvent.keyCode), keyDown: false)
    
    keyDown?.flags = CGEventFlags(rawValue: keyEvent.modifierFlags)
    keyUp?.flags = CGEventFlags(rawValue: keyEvent.modifierFlags)
    
    keyDown?.post(tap: .cgAnnotatedSessionEventTap)
    keyUp?.post(tap: .cgAnnotatedSessionEventTap)
  }

  private func simulateMouseClick(button: CGMouseButton) {
    let source = CGEventSource(stateID: .combinedSessionState)
    let currentPos = NSEvent.mouseLocation

    let clickDown = CGEvent(mouseEventSource: source, mouseType: .otherMouseDown, mouseCursorPosition: currentPos, mouseButton: button)
    let clickUp = CGEvent(mouseEventSource: source, mouseType: .otherMouseUp, mouseCursorPosition: currentPos, mouseButton: button)

    clickDown?.post(tap: .cgAnnotatedSessionEventTap)
    clickUp?.post(tap: .cgAnnotatedSessionEventTap)
  }

  private func setupEventMonitor() {
    eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved, .otherMouseDragged]) {
      [weak self] event in
      guard let self = self, self.window.isVisible else { return }

      let screenLocation = event.locationInWindow
      if let windowFrame = self.window.screen?.frame,
        windowFrame.contains(screenLocation)
      {
        let localPoint = self.window.convertPoint(fromScreen: screenLocation)
        self.userState.updateHoveredSection(for: localPoint)
      }
    }
  }

  private func removeEventMonitor() {
    if let monitor = eventMonitor {
      NSEvent.removeMonitor(monitor)
      eventMonitor = nil
    }
  }

  private func cancelOriginalMouseEvent() {
    let currentPos = NSEvent.mouseLocation
    let source = CGEventSource(stateID: .combinedSessionState)
    
    // Create and post a mouse up event to cancel the original mouse down
    let cancelEvent = CGEvent(mouseEventSource: source, mouseType: .otherMouseUp, mouseCursorPosition: currentPos, mouseButton: .center)
    cancelEvent?.post(tap: .cgAnnotatedSessionEventTap)
  }
}

class DontActivateConfiguration {
  let configuration = NSWorkspace.OpenConfiguration()

  static var shared = DontActivateConfiguration()

  init() {
    configuration.activates = false
  }
}

// Remove the KeyCodeMap and keyCodeForString function
