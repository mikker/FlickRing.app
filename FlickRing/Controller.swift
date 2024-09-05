import AppKit
import Carbon
import Cocoa
import Combine
import Defaults
import SwiftUI

class Controller {
  var window: Window!
  var userState: UserState
  private var eventMonitor: Any?
  private var scrollTimer: Timer?
  private var cancellable: AnyCancellable?
  private var initialMousePosition: CGPoint?

  init(userState: UserState) {
    self.userState = userState
    self.window = Window(controller: self)
    self.cancellable = userState.$hoveredSection
      .removeDuplicates()
      .sink { [weak self] section in
        self?.hover(section)
      }
  }

  func show() {
    self.initialMousePosition = NSEvent.mouseLocation

    window.show {
      self.setupEventMonitor()
    }
  }

  func hide() {
    let selectedSection = self.userState.hoveredSection

    if selectedSection != .none {
      cancelOriginalMouseEvent()
    }

    self.commit(selectedSection)

    window.hide {
      self.userState.clear()
    }

    removeEventMonitor()
    stopScrollTimer()
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

  private func hover(_ section: HoveredSection) {
    stopScrollTimer()

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

    switch action.type {
    case .scrollUp, .scrollDown: startScrollTimer(direction: action.type)
    default: break
    }
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
    case .scrollUp: break
    case .scrollDown: break
    }
  }

  private func simulateKeyEvent(_ keyEvent: KeyEvent?) {
    guard let keyEvent = keyEvent else { return }

    let source = CGEventSource(stateID: .combinedSessionState)

    let keyDown = CGEvent(
      keyboardEventSource: source, virtualKey: CGKeyCode(keyEvent.keyCode), keyDown: true)
    let keyUp = CGEvent(
      keyboardEventSource: source, virtualKey: CGKeyCode(keyEvent.keyCode), keyDown: false)

    keyDown?.flags = CGEventFlags(rawValue: keyEvent.modifierFlags)
    keyUp?.flags = CGEventFlags(rawValue: keyEvent.modifierFlags)

    keyDown?.post(tap: .cgAnnotatedSessionEventTap)
    keyUp?.post(tap: .cgAnnotatedSessionEventTap)
  }

  private func simulateMouseClick(button: CGMouseButton) {
    let source = CGEventSource(stateID: .combinedSessionState)
    let currentPos = NSEvent.mouseLocation

    let clickDown = CGEvent(
      mouseEventSource: source, mouseType: .otherMouseDown, mouseCursorPosition: currentPos,
      mouseButton: button)
    let clickUp = CGEvent(
      mouseEventSource: source, mouseType: .otherMouseUp, mouseCursorPosition: currentPos,
      mouseButton: button)

    clickDown?.post(tap: .cgAnnotatedSessionEventTap)
    clickUp?.post(tap: .cgAnnotatedSessionEventTap)
  }

  private func simulateScroll(amount: Double) {
    let source = CGEventSource(stateID: .combinedSessionState)

    let scrollEvent = CGEvent(
      scrollWheelEvent2Source: source,
      units: .pixel,
      wheelCount: 1,
      wheel1: Int32(amount),
      wheel2: 0,
      wheel3: 0
    )
    scrollEvent?.post(tap: .cghidEventTap)
  }

  private func startScrollTimer(direction: ActionType) {
    stopScrollTimer()

    scrollTimer = Timer.scheduledTimer(withTimeInterval: 0.01, repeats: true) { [weak self] _ in
      guard let self = self, let initialPos = self.initialMousePosition else { return }
      let currentPos = NSEvent.mouseLocation
      var distance: CGFloat
      switch direction {
      case .scrollUp:
        distance = initialPos.y - currentPos.y
      case .scrollDown:
        distance = currentPos.y - initialPos.y
      default:
        distance = 0
      }
      if direction == .scrollUp { distance = -distance }
      let scrollAmount = distance * 0.05  // Adjusted multiplier to make scrolling slower
      self.simulateScroll(amount: scrollAmount)
    }
  }

  private func stopScrollTimer() {
    scrollTimer?.invalidate()
    scrollTimer = nil
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
    let cancelEvent = CGEvent(
      mouseEventSource: source,
      mouseType: .otherMouseUp,
      mouseCursorPosition: currentPos,
      mouseButton: CGMouseButton(rawValue: UInt32(Defaults[.selectedMouseButton]))!
    )
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
