import SwiftUI

/// Gestiona el estado de autenticación de la app.
@Observable
final class AuthManager {
    var isAuthenticated = false
    var currentUser: String = ""
    var errorMessage: String?
    var isLoading = false

    private static let savedUserKey = "ctrl_saved_user"
    private static let savedPassKey = "ctrl_saved_pass"
    private static let rememberKey = "ctrl_remember"

    /// Intenta restaurar sesión guardada al arrancar la app.
    func restoreSession() async {
        let defaults = UserDefaults.standard
        guard defaults.bool(forKey: Self.rememberKey),
              let user = defaults.string(forKey: Self.savedUserKey),
              let pass = defaults.string(forKey: Self.savedPassKey) else { return }
        await login(username: user, password: pass, remember: true)
    }

    func login(username: String, password: String, remember: Bool = false) async {
        isLoading = true
        errorMessage = nil
        do {
            _ = try await APIClient.shared.login(username: username, password: password)
            let defaults = UserDefaults.standard
            if remember {
                defaults.set(true, forKey: Self.rememberKey)
                defaults.set(username, forKey: Self.savedUserKey)
                defaults.set(password, forKey: Self.savedPassKey)
            }
            await MainActor.run {
                self.currentUser = username
                self.isAuthenticated = true
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Credenciales incorrectas"
                self.isLoading = false
            }
        }
    }

    func logout() {
        isAuthenticated = false
        currentUser = ""
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: Self.rememberKey)
        defaults.removeObject(forKey: Self.savedUserKey)
        defaults.removeObject(forKey: Self.savedPassKey)
        Task { await APIClient.shared.setToken(nil) }
    }
}
