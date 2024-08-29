import Cocoa
import Combine
import SwiftUI

class Controller {
    var window: Window!
    var userState: UserState
    private var eventMonitor: Any?

    init(userState: UserState) {
        self.userState = userState
        self.window = Window(controller: self)
    }

    func show() {
        window.show() {
            self.setupEventMonitor()
        }
    }

    func hide() {
        self.commit(self.userState.hoveredSection)

        window.hide {
            self.userState.clear()
        }

        removeEventMonitor()
    }
    
    private func commit(_ section: HoveredSection) {
        switch (section) {
        case .up: print("up"); break
        case .down: print("down"); break
        case .left: print("left"); break
        case .right: print("right"); break
        default: break;
        }
    }

    private func setupEventMonitor() {
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved, .otherMouseDragged]) { [weak self] event in
            guard let self = self, self.window.isVisible else { return }
            
            let screenLocation = event.locationInWindow
            if let windowFrame = self.window.screen?.frame,
               windowFrame.contains(screenLocation) {
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
}

class DontActivateConfiguration {
    let configuration = NSWorkspace.OpenConfiguration()

    static var shared = DontActivateConfiguration()

    init() {
        configuration.activates = false
    }
}
