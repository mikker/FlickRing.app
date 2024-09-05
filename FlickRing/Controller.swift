import AppKit
import Carbon
import Cocoa
import Combine
import Defaults
import SwiftUI

class Controller {
  var window: Window!
  var userState: UserState
  private var mouseListener: MouseListener?
  private var eventMonitor: Any?
  private var scrollTimer: Timer?
  private var cancellable: AnyCancellable?
  private var initialMousePosition: CGPoint?
  private var initialEvent: CGEvent?
  @objc dynamic var isConfiguring = false
  private var moveMonitor: Any?
  private var showDelayWorkItem: DispatchWorkItem?

  init(userState: UserState) {
    self.userState = userState
    self.window = Window(controller: self)
    self.cancellable = userState.$hoveredSection
      .removeDuplicates()
      .sink { [weak self] section in
        self?.hover(section)
      }
    setupMouseListener()
  }

  private func setupMouseListener() {
    mouseListener = MouseListener { [weak self] type, event in
      return self?.handleMouseEvent(type: type, event: event) ?? false
    }
  }

  func startListeningForMouseEvents() {
    mouseListener?.startListening()
  }

  func handleMouseEvent(type: CGEventType, event: CGEvent) -> Bool {
    let buttonNumber = event.getIntegerValueField(.mouseEventButtonNumber)

    if isConfiguring {
      if buttonNumber >= 2 {
        NotificationCenter.default.post(name: .mouseButtonSelected, object: buttonNumber)
      }
      return true
    } else if buttonNumber == Defaults[.selectedMouseButton] {
      if type == .otherMouseDown {
        show(type: type, event: event)
      } else if type == .otherMouseUp {
        hide()
      }
      return true
    }

    return false
  }

  func show(type: CGEventType, event: CGEvent) {
    let initialLocation = NSEvent.mouseLocation
    self.initialMousePosition = initialLocation

    if type == .otherMouseDown {
      self.initialEvent = event
    }

    let showWindow = { [weak self] in
      guard let self = self else { return }
      if self.window.isVisible { return }
      self.window.show(at: initialLocation) {}
    }

    setupEventMonitor()
    
    cancelShowDelay()

    // Start monitoring for mouse movement
    self.moveMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.otherMouseDragged]) {
      [weak self] event in
      guard let self = self else { return }
      let currentLocation = event.locationInWindow
      let distance = hypot(
        currentLocation.x - initialLocation.x, currentLocation.y - initialLocation.y)

      if distance > 5 {
        self.cancelShowDelay()
        showWindow()
      }
    }

    // Set up delayed show if no movement
    let delayWorkItem = DispatchWorkItem { [weak self] in
      guard let self = self else { return }
      self.cancelShowDelay()
      if !self.window.isVisible {
        showWindow()
      }
    }
    self.showDelayWorkItem = delayWorkItem
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25, execute: delayWorkItem)
  }

  func hide() {
    cancelShowDelay()

    let selectedSection = self.userState.hoveredSection

    self.commit(selectedSection)

    window.hide {
      self.userState.clear()

      if let initialEvent = self.initialEvent, selectedSection == .none {
        self.simulateMouseClick(
          button: CGMouseButton(
            rawValue: UInt32(initialEvent.getIntegerValueField(.mouseEventButtonNumber)))!)
        self.initialEvent = nil
      }
    }

    removeEventMonitor()
    stopScrollTimer()
  }

  private func cancelShowDelay() {
    showDelayWorkItem?.cancel()
    showDelayWorkItem = nil

    if let monitor = self.moveMonitor {
      NSEvent.removeMonitor(monitor)
      self.moveMonitor = nil
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
      simulateMouseClick(button: CGMouseButton(rawValue: UInt32(action.mouseButton)) ?? .center)
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

    keyDown?.post(tap: .cghidEventTap)
    keyUp?.post(tap: .cghidEventTap)
  }

  private func simulateMouseClick(button: CGMouseButton) {
    let source = CGEventSource(stateID: .combinedSessionState)
    let currentPos = NSEvent.mouseLocation
    let cgCurrentLocation = CGPoint(
      x: currentPos.x, y: CGFloat(NSScreen.main?.frame.height ?? 0) - currentPos.y)

    mouseListener?.executeWithoutListening {
      let clickDown = CGEvent(
        mouseEventSource: source, mouseType: .otherMouseDown,
        mouseCursorPosition: cgCurrentLocation,
        mouseButton: button)
      let clickUp = CGEvent(
        mouseEventSource: source, mouseType: .otherMouseUp, mouseCursorPosition: cgCurrentLocation,
        mouseButton: button)

      clickDown?.post(tap: .cghidEventTap)
      clickUp?.post(tap: .cghidEventTap)
    }
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

  func setConfiguring(_ configuring: Bool) {
    isConfiguring = configuring
  }
}

class DontActivateConfiguration {
  let configuration = NSWorkspace.OpenConfiguration()

  static var shared = DontActivateConfiguration()

  init() {
    configuration.activates = false
  }
}
