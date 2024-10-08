import Defaults
import SwiftUI

enum HoveredSection: String {
  case up, right, down, left, none
}

final class UserState: ObservableObject {
  @Published var hoveredSection: HoveredSection = .none

  init(hoveredSection: HoveredSection = .none) {
    self.hoveredSection = hoveredSection
  }

  func updateHoveredSection(for point: NSPoint) {
    let center = CGPoint(x: MainView.size / 2, y: MainView.size / 2)
    let dx = point.x - center.x
    let dy = point.y - center.y

    if dx * dx + dy * dy <= (MainView.centerSize / 2) * (MainView.centerSize / 2) {
      hoveredSection = .none
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
  }

  func clear() {
    hoveredSection = .none
  }
}
