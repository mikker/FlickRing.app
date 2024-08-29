//
//  MainView.swift
//  Leader Key
//
//  Created by Mikkel Malmberg on 19/04/2024.
//

import SwiftUI

struct MainView: View {
    @ObservedObject var userState: UserState
    
    init(userState: UserState) {
        self._userState = ObservedObject(wrappedValue: userState)
    }
    
    static let size: CGFloat = 200
    static let centerSize: CGFloat = 50
    
    var body: some View {
        ZStack {
            backgroundCircle
            radialSections
            sectionLabels
            centerCircle
            middleLabel
            MouseTrackingViewRepresentable(userState: userState) { location in
                if let location = location {
                    self.updateHoveredSection(for: location)
                } else {
                    self.userState.hoveredSection = .none
                }
            }
            .allowsHitTesting(false)
        }
        .frame(width: MainView.size, height: MainView.size)
    }
    
    private var backgroundCircle: some View {
        VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
            .clipShape(Circle())
            .frame(width: MainView.size, height: MainView.size)
    }
    
    private var radialSections: some View {
        ForEach(0..<4, id: \.self) { index in
            RadialSection(startAngle: Double(index) * 90 + 45, endAngle: Double(index + 1) * 90 + 45)
                .fill(sectionColor(for: index))
                .overlay(
                    RadialSection(startAngle: Double(index) * 90 + 45, endAngle: Double(index + 1) * 90 + 45)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )
        }
    }
    
    private func sectionColor(for index: Int) -> Color {
        let section: HoveredSection = [.up, .right, .down, .left][index]
        return userState.hoveredSection == section ? Color.blue.opacity(0.3) : Color.gray.opacity(0.1)
    }
    
    private var sectionLabels: some View {
        VStack {
            Text("Up").offset(y: -MainView.size/5)
            HStack {
                Text("Left").offset(x: -MainView.size/5)
                Spacer().frame(width: MainView.centerSize)
                Text("Right").offset(x: MainView.size/5)
            }
            Text("Down").offset(y: MainView.size/5)
        }
        .font(.system(size: 12))
    }
    
    private var centerCircle: some View {
        VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
            .clipShape(Circle())
            .overlay(Circle().stroke(Color.gray.opacity(0.3), lineWidth: 1))
            .frame(width: MainView.centerSize, height: MainView.centerSize)
            .background(
                Circle()
                    .fill(userState.hoveredSection == .middle ? Color.blue.opacity(0.3) : Color.clear)
                    .frame(width: MainView.centerSize, height: MainView.centerSize)
            )
    }
    
    private var middleLabel: some View {
        Text("Middle")
            .font(.system(size: 10))
    }
    
    private func updateHoveredSection(for point: NSPoint) {
        let center = CGPoint(x: MainView.size / 2, y: MainView.size / 2)
        let dx = point.x - center.x
        let dy = point.y - center.y
        
        if dx * dx + dy * dy <= (MainView.centerSize / 2) * (MainView.centerSize / 2) {
            userState.hoveredSection = .middle
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
        
        print("Hovered section: \(userState.hoveredSection)")
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
        path.addArc(center: center, radius: radius, startAngle: .degrees(startAngle), endAngle: .degrees(endAngle), clockwise: false)
        path.closeSubpath()
        return path
    }
}

struct MainView_Previews: PreviewProvider {
    static var previews: some View {
        MainView(userState: UserState())
    }
}
