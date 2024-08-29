import Defaults
import LaunchAtLogin
import Settings
import SwiftUI

struct GeneralPane: View {
    @EnvironmentObject var userState: UserState
    @State private var isListening = false
    private let contentWidth = 480.0

    var body: some View {
        Settings.Container(contentWidth: contentWidth) {
            Settings.Section(title: "App") {
                LaunchAtLogin.Toggle()
            }
            
            Settings.Section(title: "Mouse Configuration") {
                HStack {
                    Text("Selected Mouse Button: \(buttonName(for: userState.selectedMouseButton))")
                    Spacer()
                    Button(isListening ? "Listening..." : "Configure") {
                        if !isListening {
                            isListening = true
                            NotificationCenter.default.post(name: .startListeningForMouseButton, object: nil)
                        }
                    }
                    .disabled(isListening)
                }

            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .mouseButtonSelected)) { notification in
            if let buttonNumber = notification.object as? Int {
                userState.selectedMouseButton = buttonNumber
                Defaults[.selectedMouseButton] = buttonNumber
                isListening = false
            }
        }
    }
    
    private func buttonName(for buttonNumber: Int) -> String {
        switch buttonNumber {
        case 2: return "Middle Button (Scroll Wheel)"
        default: return "Button \(buttonNumber)"
        }
    }
}

struct GeneralPane_Previews: PreviewProvider {
    static var previews: some View {
        GeneralPane().environmentObject(UserState())
    }
}

