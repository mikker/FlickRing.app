import Defaults
import LaunchAtLogin
import Settings
import SwiftUI
import AppKit

struct ModifierFlags: OptionSet, Hashable, Codable, Defaults.Serializable, CaseIterable {
  let rawValue: Int

  static let cmd = ModifierFlags(rawValue: 1 << 0)
  static let opt = ModifierFlags(rawValue: 1 << 1)
  static let shift = ModifierFlags(rawValue: 1 << 2)
  static let ctrl = ModifierFlags(rawValue: 1 << 3)

  static var allCases: [ModifierFlags] = [.cmd, .opt, .shift, .ctrl]
}

struct GeneralPane: View {
  @State private var isListening = false
  @Default(.selectedMouseButton) private var selectedMouseButton

  @Default(.upAction) private var upAction
  @Default(.downAction) private var downAction
  @Default(.leftAction) private var leftAction
  @Default(.rightAction) private var rightAction

  @State private var lastKeyPressed: String = ""
  @FocusState private var focusedField: String?

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

      Settings.Section(title: "App") {
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
    NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { event in
      if let field = focusedField, event.type == .keyDown {
        if let actionConfig = self.getActionConfig(for: field) {
          actionConfig.key.wrappedValue = self.keyToGlyph(event)
          actionConfig.modifiers.wrappedValue = ModifierFlags(event: event)
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
    VStack(alignment: .leading) {
      Text(title)
        .frame(width: 69, alignment: .leading)

      HStack(alignment: .top) {
        Picker("", selection: config.type) {
          ForEach(ActionType.allCases) { actionType in
            Text(actionType.rawValue).tag(actionType)
          }
        }
        .frame(width: 180)

        switch config.wrappedValue.type {
        case .doNothing:
          EmptyView()
        case .sendKey:
          TextField(
            "Key",
            text: .constant(config.modifiers.wrappedValue.keyEquivalent + config.key.wrappedValue)
          )
          .frame(width: 80)
          .multilineTextAlignment(.center)
          .focused($focusedField, equals: title)
        case .pressMouseButton:
          HStack {
            Picker("", selection: config.mouseButton) {
              ForEach(2...9, id: \.self) { button in
                Text("\(button)").tag(button)
              }
            }
            .frame(width: 50)
          }
        case .openURL:
          HStack {
            TextField("", text: config.url)
          }
        }
      }
    }
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
}

struct ModifierPicker: View {
  @Binding var selectedModifiers: ModifierFlags

  var body: some View {
    HStack(spacing: 4) {
      ToggleButton(
        title: "⌘", isSelected: selectedModifiers.contains(.cmd), action: { toggle(.cmd) })
      ToggleButton(
        title: "⌥", isSelected: selectedModifiers.contains(.opt), action: { toggle(.opt) })
      ToggleButton(
        title: "⇧", isSelected: selectedModifiers.contains(.shift), action: { toggle(.shift) })
      ToggleButton(
        title: "⌃", isSelected: selectedModifiers.contains(.ctrl), action: { toggle(.ctrl) })
    }
  }

  private func toggle(_ modifier: ModifierFlags) {
    if selectedModifiers.contains(modifier) {
      selectedModifiers.remove(modifier)
    } else {
      selectedModifiers.insert(modifier)
    }
  }
}

struct ToggleButton: View {
  let title: String
  let isSelected: Bool
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      Text(title)
        .font(.system(size: 12))
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(isSelected ? Color.accentColor : Color.clear)
        .foregroundColor(isSelected ? .white : .primary)
        .cornerRadius(4)
    }
    .buttonStyle(PlainButtonStyle())
  }
}

struct GeneralPane_Previews: PreviewProvider {
  static var previews: some View {
    GeneralPane()
  }
}

extension ModifierFlags {
  init(event: NSEvent) {
    self.init()
    if event.modifierFlags.contains(.command) { self.insert(.cmd) }
    if event.modifierFlags.contains(.option) { self.insert(.opt) }
    if event.modifierFlags.contains(.shift) { self.insert(.shift) }
    if event.modifierFlags.contains(.control) { self.insert(.ctrl) }
  }

  var keyEquivalent: String {
    var result = ""
    if self.contains(.ctrl) { result += "^" }
    if self.contains(.opt) { result += "⌥" }
    if self.contains(.shift) { result += "⇧" }
    if self.contains(.cmd) { result += "⌘" }
    return result
  }
}
