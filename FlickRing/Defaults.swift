//
//  Defaults.swift
//  FlickRing
//
//  Created by Mikkel Malmberg on 29/08/2024.
//

import Defaults

extension Defaults.Keys {
  static let selectedMouseButton = Key<Int>("selectedMouseButton", default: 2)  // Default to middle button
  static let upAction = Key<ActionConfig>("upAction", default: ActionConfig())
  static let downAction = Key<ActionConfig>("downAction", default: ActionConfig())
  static let leftAction = Key<ActionConfig>("leftAction", default: ActionConfig())
  static let rightAction = Key<ActionConfig>("rightAction", default: ActionConfig())
}

enum ActionType: String, CaseIterable, Identifiable, Codable {
  case doNothing = "Do nothing"
  case sendKey = "Send Key"
  case pressMouseButton = "Mouse Button"
  case openURL = "Open URL"

  var id: String { self.rawValue }
}

struct ActionConfig: Codable, Defaults.Serializable {
  var type: ActionType = .doNothing
  var keyCode: Int = 0
  var mouseButton: Int = 2
  var url: String = ""
  var modifiers: ModifierFlags = []
  var key: String = ""
}
