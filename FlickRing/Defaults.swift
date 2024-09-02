//
//  Defaults.swift
//  FlickRing
//
//  Created by Mikkel Malmberg on 29/08/2024.
//

import AppKit
import Carbon
import Defaults

extension Defaults.Keys {
  static let selectedMouseButton = Key<Int>("selectedMouseButton", default: 2)  // Default to middle button
  static let upAction = Key<ActionConfig>("upAction", default: ActionConfig())
  static let downAction = Key<ActionConfig>("downAction", default: ActionConfig())
  static let leftAction = Key<ActionConfig>("leftAction", default: ActionConfig())
  static let rightAction = Key<ActionConfig>("rightAction", default: ActionConfig())
  static let selectedTheme = Key<Theme>("selectedTheme", default: .system)
  static let showPreferencesOnLaunch = Key<Bool>("showPreferencesOnLaunch", default: true)
}

enum ActionType: String, CaseIterable, Identifiable, Codable {
  case doNothing = "Do nothing"
  case sendKey = "Send Key"
  case pressMouseButton = "Mouse Button"
  case openURL = "Open URL"
  case scrollUp = "Scroll Up"
  case scrollDown = "Scroll Down"

  var id: String { self.rawValue }
}

struct ActionConfig: Codable, Defaults.Serializable {
  var type: ActionType = .doNothing
  var keyEvent: KeyEvent?
  var mouseButton: Int = 2
  var url: String = ""
}

struct KeyEvent: Codable, Defaults.Serializable {
  var keyCode: UInt16
  var modifierFlags: UInt64

  init(keyCode: UInt16, modifierFlags: UInt64) {
    self.keyCode = keyCode
    self.modifierFlags = modifierFlags
  }

  init(nsEvent: NSEvent) {
    self.keyCode = nsEvent.keyCode
    self.modifierFlags = UInt64(nsEvent.modifierFlags.rawValue)
  }

  var character: String {
    let source = CGEventSource(stateID: .combinedSessionState)
    guard
      let event = CGEvent(
        keyboardEventSource: source, virtualKey: CGKeyCode(keyCode), keyDown: true)
    else {
      return "?"
    }
    event.flags = CGEventFlags(rawValue: modifierFlags)

    let nsEvent = NSEvent(cgEvent: event)
    return nsEvent?.charactersIgnoringModifiers ?? "?"
  }
}
