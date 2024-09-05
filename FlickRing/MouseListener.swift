import Cocoa

typealias Handler = (CGEventType, CGEvent) -> Bool

class MouseListener {
  private var eventHandler: Handler?
  private var eventTap: CFMachPort?

  init(handler: @escaping Handler) {
    self.eventHandler = handler
  }

  func startListening() {
    let eventMask =
      (1 << CGEventType.otherMouseDown.rawValue) | (1 << CGEventType.otherMouseUp.rawValue)

    guard
      let eventTap = CGEvent.tapCreate(
        tap: .cghidEventTap,
        place: .headInsertEventTap,
        options: .defaultTap,
        eventsOfInterest: CGEventMask(eventMask),
        callback: { (proxy, type, event, refcon) -> Unmanaged<CGEvent>? in
          let listener = Unmanaged<MouseListener>.fromOpaque(refcon!).takeUnretainedValue()
          let shouldHandle = listener.eventHandler?(type, event) ?? false
          return shouldHandle ? nil : Unmanaged.passRetained(event)
        },
        userInfo: Unmanaged.passUnretained(self).toOpaque()
      )
    else {
      print("Failed to create event tap")
      return
    }

    self.eventTap = eventTap

    let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
    CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
    CGEvent.tapEnable(tap: eventTap, enable: true)
  }

  func executeWithoutListening(_ callback: () -> Void) {
    guard let eventTap = eventTap else { return }

    CGEvent.tapEnable(tap: eventTap, enable: false)
    callback()
    CGEvent.tapEnable(tap: eventTap, enable: true)
  }

  deinit {
    if let eventTap = eventTap {
      CGEvent.tapEnable(tap: eventTap, enable: false)
    }
  }
}
