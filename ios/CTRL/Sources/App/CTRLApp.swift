import SwiftUI

@main
struct CTRLApp: App {
    @State private var authManager = AuthManager()

    var body: some Scene {
        WindowGroup {
            Group {
                if authManager.isCheckingSession {
                    Color.clear.onAppear {
                        authManager.checkSavedSession()
                    }
                } else if authManager.isAuthenticated {
                    MainView()
                        .environment(authManager)
                } else {
                    LoginView()
                        .environment(authManager)
                }
            }
        }
    }
}
