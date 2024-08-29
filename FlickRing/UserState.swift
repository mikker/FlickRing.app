import SwiftUI
import Defaults

enum HoveredSection: String {
    case up, right, down, left, middle, none
}

final class UserState: ObservableObject {
    @Published var selectedMouseButton: Int = Defaults[.selectedMouseButton]
    @Published var hoveredSection: HoveredSection = .none

    init() {}
}

extension Defaults.Keys {
    static let selectedMouseButton = Key<Int>("selectedMouseButton", default: 2) // Default to middle button
}
