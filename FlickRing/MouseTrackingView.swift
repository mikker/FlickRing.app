import SwiftUI
import AppKit

class MouseTrackingView: NSView {
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
        print("Tracking area set up with bounds: \(bounds)")
    }
    
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        for trackingArea in trackingAreas {
            removeTrackingArea(trackingArea)
        }
        setupTracking()
        print("Tracking areas updated")
    }
    
    override func mouseMoved(with event: NSEvent) {
        DispatchQueue.main.async {
            let location = self.convert(event.locationInWindow, from: nil)
            print("Mouse moved to: \(location), event: \(event)")
            self.mouseLocationHandler?(location)
        }
    }
    
    override func mouseExited(with event: NSEvent) {
        mouseLocationHandler?(nil)
    }
}

struct MouseTrackingViewRepresentable: NSViewRepresentable {
    var mouseLocationHandler: (NSPoint?) -> Void
    
    func makeNSView(context: Context) -> MouseTrackingView {
        let view = MouseTrackingView()
        view.mouseLocationHandler = mouseLocationHandler
        return view
    }
    
    func updateNSView(_ nsView: MouseTrackingView, context: Context) {}
}
