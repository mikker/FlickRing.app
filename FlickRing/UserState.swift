import SwiftUI
import Defaults

enum HoveredSection: String {
    case up, right, down, left, middle, none
}

final class UserState: ObservableObject {
    @Published var selectedMouseButton: Int = Defaults[.selectedMouseButton]
    @Published var hoveredSection: HoveredSection = .none

    init() {}

    func updateHoveredSection(for point: NSPoint) {
        let center = CGPoint(x: MainView.size / 2, y: MainView.size / 2)
        let dx = point.x - center.x
        let dy = point.y - center.y
        
        if dx * dx + dy * dy <= (MainView.centerSize / 2) * (MainView.centerSize / 2) {
            hoveredSection = .middle
        } else {
            let angle = atan2(dy, dx) * (180 / .pi)
            if angle >= -45 && angle < 45 {
                hoveredSection = .right
            } else if angle >= 45 && angle < 135 {
                hoveredSection = .up
            } else if angle >= 135 || angle < -135 {
                hoveredSection = .left
            } else {
                hoveredSection = .down
            }
        }
        
        print("Hovered section: \(hoveredSection)")
    }
    
    func clear() {
        hoveredSection = .middle
    }
}

extension Defaults.Keys {
    static let selectedMouseButton = Key<Int>("selectedMouseButton", default: 2) // Default to middle button
}
