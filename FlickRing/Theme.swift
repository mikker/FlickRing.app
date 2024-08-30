import Defaults
import SwiftUI

enum Theme: String, CaseIterable, Identifiable, Defaults.Serializable {
  case system, rainbow, blue, purple, pink, red, orange, yellow, green, graphite

  var id: String { self.rawValue }

  var gradient: Gradient {
    switch self {
    case .system:
      return Gradient(colors: [Color.white.opacity(0.2), Color.white.opacity(0.2)])
    case .blue:
      return Gradient(colors: [Color.blue, Color.blue])
    case .purple:
      return Gradient(colors: [Color.purple, Color.purple])
    case .pink:
      return Gradient(colors: [Color.pink, Color.pink])
    case .red:
      return Gradient(colors: [Color.red, Color.red])
    case .orange:
      return Gradient(colors: [Color.orange, Color.orange])
    case .yellow:
      return Gradient(colors: [Color.yellow, Color.yellow])
    case .green:
      return Gradient(colors: [Color.green, Color.green])
    case .graphite:
      return Gradient(colors: [Color.gray, Color.gray])
    case .rainbow:
      return Gradient(colors: [.red, .orange, .yellow, .green, .blue, .purple, .red])
    }
  }
}
