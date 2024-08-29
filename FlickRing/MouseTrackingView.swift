import SwiftUI
import AppKit

class MouseTrackingView: NSView {
    var userState: UserState?
    
    var mouseLocationHandler: ((NSPoint?) -> Void)?
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupTracking()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupTracking()
    }
    
    private func setupTracking() {
        let options: NSTrackingArea.Options = [.mouseEnteredAndExited, .mouseMoved, .activeAlways]
        let trackingArea = NSTrackingArea(rect: bounds, options: options, owner: self, userInfo: nil)
        addTrackingArea(trackingArea)
    }
    
    override func mouseMoved(with event: NSEvent) {
        let location = convert(event.locationInWindow, from: nil)
        mouseLocationHandler?(location)
        userState?.objectWillChange.send() // Notify observers of change
    }
    
    override func mouseExited(with event: NSEvent) {
        mouseLocationHandler?(nil)
    }
}

struct MouseTrackingViewRepresentable: NSViewRepresentable {
    @ObservedObject var userState: UserState
    var mouseLocationHandler: (NSPoint?) -> Void
    
    func makeNSView(context: Context) -> MouseTrackingView {
        let view = MouseTrackingView()
        view.userState = userState
        view.mouseLocationHandler = mouseLocationHandler
        return view
    }
    
    func updateNSView(_ nsView: MouseTrackingView, context: Context) {}
}