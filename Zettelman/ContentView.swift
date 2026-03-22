import SwiftUI

struct ContentView: View {
    @StateObject private var authManager = CognitoAuthManager()

    var body: some View {
        Group {
            if authManager.isSignedIn {
                AppointmentListView()
                    .environmentObject(authManager)
            } else {
                CognitoAuthView()
                    .environmentObject(authManager)
            }
        }
    }
}
