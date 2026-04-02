import SwiftUI

@main
struct CTRLApp: App {
    @State private var authManager = AuthManager()
    @State private var isRestoring = true

    var body: some Scene {
        WindowGroup {
            if isRestoring {
                // Pantalla de carga mientras intenta restaurar sesión
                VStack(spacing: 16) {
                    Image(systemName: "map.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(.blue)
                    ProgressView()
                }
                .task {
                    await authManager.restoreSession()
                    isRestoring = false
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
