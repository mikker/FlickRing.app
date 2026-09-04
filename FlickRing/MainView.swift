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
  @Default(.glassStyle) private var glassStyle: GlassStyle

  init(userState: UserState) {
    self._userState = ObservedObject(wrappedValue: userState)
  }

  static let size: CGFloat = 160
  static let centerSize: CGFloat = 70

  var body: some View {
    ZStack {
      background
      radialSections
    }
    .mask(ringMask)
    .frame(width: MainView.size, height: MainView.size)
  }

  @ViewBuilder
  private var background: some View {
    if #available(macOS 26, *) {
      glassRing
      if selectedTheme != .system {
        themeCircle.opacity(0.6)
      }
    } else if selectedTheme == .system {
      VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
        .frame(width: MainView.size, height: MainView.size)
    } else {
      themeCircle
    }
  }

  @available(macOS 26, *)
  private var glassRing: some View {
    Color.clear
      .frame(width: MainView.size, height: MainView.size)
      .glassEffect(glassStyle.glass, in: RingShape(holeSize: MainView.centerSize))
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
        .fill(sectionColor(for: index))
    }
  }

  private func sectionColor(for index: Int) -> Color {
    let section: HoveredSection = [.down, .left, .up, .right][index]
    let isHovered = userState.hoveredSection == section
    if #available(macOS 26, *), selectedTheme == .system {
      return isHovered ? Color.gray.opacity(0.2) : Color.clear
    }
    let minimumOpacity = selectedTheme == .system ? 0.2 : 0.0
    return Color.white.opacity(isHovered ? 0.5 : minimumOpacity)
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
}

struct RingShape: Shape {
  let holeSize: CGFloat

  func path(in rect: CGRect) -> Path {
    var path = Path()
    let center = CGPoint(x: rect.midX, y: rect.midY)
    path.addArc(
      center: center, radius: min(rect.width, rect.height) / 2, startAngle: .zero,
      endAngle: .degrees(360), clockwise: false)
    path.closeSubpath()
    path.addArc(
      center: center, radius: holeSize / 2, startAngle: .zero, endAngle: .degrees(360),
      clockwise: true)
    path.closeSubpath()
    return path
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
