import SwiftUI

@main
struct CTRLApp: App {
    @State private var authManager = AuthManager()

    var body: some Scene {
        WindowGroup {
            if authManager.isAuthenticated {
                MainView()
                    .environment(authManager)
            } else {
                LoginView()
                    .environment(authManager)
            }
        }
    }
}
