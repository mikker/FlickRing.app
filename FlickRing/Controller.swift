import Cocoa
import Combine
import SwiftUI

class Controller {
    var window: Window!
    var userState: UserState

    init(userState: UserState) {
        self.userState = userState
        
        self.window = Window(controller: self)
    }

    func show() {
        window.show()
    }

    func hide() {
        window.hide {
            let selectedSection = self.userState.hoveredSection
            print("Selected section: \(selectedSection)")
            // Add your logic here to handle the selected section
            self.userState.hoveredSection = .none // Reset the hovered section
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
