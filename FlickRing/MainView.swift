//
//  MainView.swift
//  Leader Key
//
//  Created by Mikkel Malmberg on 19/04/2024.
//

import Defaults
import SwiftUI

struct MainView: View {
  @ObservedObject var userState: UserState
  @Default(.selectedTheme) private var selectedTheme: Theme

  init(userState: UserState) {
    self._userState = ObservedObject(wrappedValue: userState)
  }

  static let size: CGFloat = 160
  static let centerSize: CGFloat = 70

  var body: some View {
    ZStack {
      if selectedTheme == .system {
        systemThemeView
      } else {
        themeCircle
      }
      radialSections
    }
    .mask(ringMask)
    .frame(width: MainView.size, height: MainView.size)
  }

  private var systemThemeView: some View {
    VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
      .frame(width: MainView.size, height: MainView.size)
  }

  private var themeCircle: some View {
    Circle()
      .fill(
        AngularGradient(
          gradient: selectedTheme.gradient,
          center: .center
        )
      )
      .frame(width: MainView.size, height: MainView.size)
  }

  private var radialSections: some View {
    ForEach(0..<4, id: \.self) { index in
      RadialSection(startAngle: Double(index) * 90 + 45, endAngle: Double(index + 1) * 90 + 45)
        .fill(Color.white.opacity(sectionOpacity(for: index)))
        .overlay(
          RadialSection(startAngle: Double(index) * 90 + 45, endAngle: Double(index + 1) * 90 + 45)
            .stroke(Color.clear)
        )
    }
  }

  private func sectionOpacity(for index: Int) -> Double {
    let section: HoveredSection = [.down, .left, .up, .right][index]
    let minimumOpacity = selectedTheme == .system ? 0.2 : 0.0
    return userState.hoveredSection == section ? 0.5 : minimumOpacity
  }

  private var ringMask: some View {
    Circle()
      .frame(width: MainView.size, height: MainView.size)
      .overlay(
        Circle()
          .fill(Color.black)
          .frame(width: MainView.centerSize, height: MainView.centerSize)
          .blendMode(.destinationOut)
      )
  }

  private func updateHoveredSection(for point: NSPoint) {
    let center = CGPoint(x: MainView.size / 2, y: MainView.size / 2)
    let dx = point.x - center.x
    let dy = point.y - center.y

    if dx * dx + dy * dy <= (MainView.centerSize / 2) * (MainView.centerSize / 2) {
      userState.hoveredSection = .none
    } else {
      let angle = atan2(dy, dx) * (180 / .pi)
      if angle >= -45 && angle < 45 {
        userState.hoveredSection = .right
      } else if angle >= 45 && angle < 135 {
        userState.hoveredSection = .up
      } else if angle >= 135 || angle < -135 {
        userState.hoveredSection = .left
      } else {
        userState.hoveredSection = .down
      }
    }
  }
}

struct RadialSection: Shape {
  let startAngle: Double
  let endAngle: Double

  func path(in rect: CGRect) -> Path {
    var path = Path()
    let center = CGPoint(x: rect.midX, y: rect.midY)
    let radius = min(rect.width, rect.height) / 2
    path.move(to: center)
    path.addArc(
      center: center, radius: radius, startAngle: .degrees(startAngle),
      endAngle: .degrees(endAngle), clockwise: false)
    path.closeSubpath()
    return path
  }
}

struct VisualEffectView: NSViewRepresentable {
  let material: NSVisualEffectView.Material
  let blendingMode: NSVisualEffectView.BlendingMode

  func makeNSView(context: Context) -> NSVisualEffectView {
    let visualEffectView = NSVisualEffectView()
    visualEffectView.material = material
    visualEffectView.blendingMode = blendingMode
    visualEffectView.state = .active
    return visualEffectView
  }

  func updateNSView(_ visualEffectView: NSVisualEffectView, context: Context) {
    visualEffectView.material = material
    visualEffectView.blendingMode = blendingMode
  }
}

struct MainView_Previews: PreviewProvider {
  static var previews: some View {
    MainView(userState: UserState(hoveredSection: .left))
  }
}
