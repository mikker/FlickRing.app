import AppKit
import Defaults
import LaunchAtLogin
import Settings
import SwiftUI

struct GeneralPane: View {
  @State private var isListening = false
  @Default(.selectedMouseButton) private var selectedMouseButton

  @Default(.upAction) private var upAction
  @Default(.downAction) private var downAction
  @Default(.leftAction) private var leftAction
  @Default(.rightAction) private var rightAction

  @State private var lastKeyPressed: String = ""
  @FocusState private var focusedField: String?

  @Default(.selectedTheme) private var selectedTheme

  private let contentWidth = 480.0

  var body: some View {
    Settings.Container(contentWidth: contentWidth) {
      Settings.Section(title: "Activator", bottomDivider: true) {
        HStack {
          Button(isListening ? "Cancel" : "Configure") {
            isListening.toggle()
            NotificationCenter.default.post(name: .configurationStateChanged, object: isListening)
          }
          TextField("", text: .constant(buttonName(for: selectedMouseButton)))
            .disabled(true)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
      }

      Settings.Section(title: "Actions", bottomDivider: true) {
        actionRow(title: "Up", config: $upAction)
        actionRow(title: "Down", config: $downAction)
        actionRow(title: "Left", config: $leftAction)
        actionRow(title: "Right", config: $rightAction)
      }

      Settings.Section(title: "Appearance", bottomDivider: true, verticalAlignment: .center) {
        HStack {
          ForEach(Theme.allCases) { theme in
            Button(action: {
              selectedTheme = theme
            }) {
              themePreview(for: theme)
                .frame(width: 30, height: 30)
            }
            .buttonStyle(PlainButtonStyle())
            .background(selectedTheme == theme ? Color.accentColor.opacity(0.2) : Color.clear)
            .cornerRadius(4)
          }
        }
      }

      Settings.Section(title: "App") {
        Defaults.Toggle("Show this window on launch", key: .showPreferencesOnLaunch)
        LaunchAtLogin.Toggle()
      }

    }
    .onAppear {
      setupKeyboardMonitor()
    }
    .onReceive(NotificationCenter.default.publisher(for: .mouseButtonSelected)) { notification in
      if let buttonNumber = notification.object as? Int, buttonNumber >= 2 {
        selectedMouseButton = buttonNumber
        isListening = false
        NotificationCenter.default.post(name: .configurationStateChanged, object: false)
      }
    }
  }

  private func setupKeyboardMonitor() {
    NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { event in
      if let field = focusedField {
        if let actionConfig = self.getActionConfig(for: field) {
          actionConfig.wrappedValue.keyEvent = KeyEvent(nsEvent: event)
        }
        focusedField = nil
        return nil
      }
      return event
    }
  }

  private func startListeningForMouseButton() {
    isListening = true
    NotificationCenter.default.post(name: .configurationStateChanged, object: true)
  }

  private func stopListeningForMouseButton() {
    isListening = false
    NotificationCenter.default.post(name: .configurationStateChanged, object: false)
  }

  private func actionRow(title: String, config: Binding<ActionConfig>) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(title)
        .font(.headline)
        .frame(width: 69, alignment: .leading)

      HStack(alignment: .top, spacing: 12) {
        Picker(selection: config.type, label: EmptyView()) {
          ForEach(ActionType.allCases) { actionType in
            Text(actionType.rawValue).tag(actionType)
          }
        }
        .labelsHidden()
        .frame(width: 140)

        switch config.wrappedValue.type {
        case .doNothing:
          EmptyView()
        case .sendKey:
          TextField("Key", text: .constant(keyEventToString(config.wrappedValue.keyEvent)))
            .frame(width: 80)
            .multilineTextAlignment(.center)
            .focused($focusedField, equals: title)
        case .pressMouseButton:
          Picker(selection: config.mouseButton, label: EmptyView()) {
            ForEach(2...9, id: \.self) { button in
              Text("\(button)").tag(button)
            }
          }
          .labelsHidden()
          .frame(width: 50)
        case .openURL:
          TextField("", text: config.url)
        }
      }
    }
    .padding(.vertical, 4)
  }

  private func getActionConfig(for field: String) -> Binding<ActionConfig>? {
    switch field {
    case "Up": return $upAction
    case "Down": return $downAction
    case "Left": return $leftAction
    case "Right": return $rightAction
    default: return nil
    }
  }

  private func buttonName(for buttonNumber: Int) -> String {
    switch buttonNumber {
    default: return "Button \(buttonNumber)"
    }
  }

  private func keyEventToString(_ keyEvent: KeyEvent?) -> String {
    guard let keyEvent = keyEvent else { return "" }

    var modifierString = ""
    let flags = CGEventFlags(rawValue: keyEvent.modifierFlags)

    if flags.contains(.maskControl) { modifierString += "⌃" }
    if flags.contains(.maskAlternate) { modifierString += "⌥" }
    if flags.contains(.maskShift) { modifierString += "⇧" }
    if flags.contains(.maskCommand) { modifierString += "⌘" }

    return modifierString + keyEvent.character
  }

  private func keyToGlyph(_ event: NSEvent) -> String {
    let keyMap: [Int: String] = [
      126: "↑",  // Up Arrow
      125: "↓",  // Down Arrow
      123: "←",  // Left Arrow
      124: "→",  // Right Arrow
      36: "↩",  // Return
      51: "⌫",  // Delete (Backspace)
      115: "↖",  // Home
      119: "↘",  // End
      48: "⇥",  // Tab
      49: "Space",
      53: "⎋",  // Escape
    ]

    if let glyph = keyMap[Int(event.keyCode)] {
      return glyph
    }

    // For printable characters, use charactersIgnoringModifiers
    if let char = event.charactersIgnoringModifiers, !char.isEmpty {
      return char.uppercased()
    }

    // If we can't interpret the key, return a placeholder
    return "?"
  }

  private func themePreview(for theme: Theme) -> some View {
    Group {
      if theme == .rainbow {
        Circle()
          .fill(AngularGradient(gradient: theme.gradient, center: .center))
      } else if theme == .system {
        GeometryReader { geometry in
          Path { path in
            path.move(to: .zero)
            path.addLine(to: CGPoint(x: geometry.size.width, y: 0))
            path.addLine(to: CGPoint(x: geometry.size.width, y: geometry.size.height))
            path.addLine(to: CGPoint(x: 0, y: geometry.size.height))
            path.closeSubpath()
          }
          .fill(Color.white)

          Path { path in
            path.move(to: .zero)
            path.addLine(to: CGPoint(x: geometry.size.width, y: geometry.size.height))
            path.addLine(to: CGPoint(x: 0, y: geometry.size.height))
            path.closeSubpath()
          }
          .fill(Color.gray)
        }
        .clipShape(Circle())
      } else {
        Circle()
          .fill(LinearGradient(gradient: theme.gradient, startPoint: .leading, endPoint: .trailing))
      }
    }
    .frame(width: 12, height: 12)
  }
}

struct GeneralPane_Previews: PreviewProvider {
  static var previews: some View {
    GeneralPane()
  }
}
