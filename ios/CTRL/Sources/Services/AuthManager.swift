import SwiftUI

/// Gestiona el estado de autenticación de la app.
@Observable
final class AuthManager {
    var isAuthenticated = false
    var currentUser: String = ""
    var errorMessage: String?
    var isLoading = false

    /// true mientras se comprueba si hay sesión guardada (solo al arrancar).
    var isCheckingSession = true

    private static let savedUserKey = "ctrl_saved_user"
    private static let savedPassKey = "ctrl_saved_pass"
    private static let rememberKey = "ctrl_remember"
    private static let savedTokenKey = "ctrl_saved_token"

    /// Comprueba si hay sesión guardada. Si la hay, restaura sin llamar a la API.
    func checkSavedSession() {
        let defaults = UserDefaults.standard
        if defaults.bool(forKey: Self.rememberKey),
           let user = defaults.string(forKey: Self.savedUserKey),
           let token = defaults.string(forKey: Self.savedTokenKey) {
            // Restaurar sesión directamente con el token guardado
            currentUser = user
            isAuthenticated = true
            Task { await APIClient.shared.setToken(token) }
        }
        isCheckingSession = false
    }

    func login(username: String, password: String, remember: Bool = false) async {
        isLoading = true
        errorMessage = nil
        do {
            let token = try await APIClient.shared.login(username: username, password: password)
            if remember {
                let defaults = UserDefaults.standard
                defaults.set(true, forKey: Self.rememberKey)
                defaults.set(username, forKey: Self.savedUserKey)
                defaults.set(password, forKey: Self.savedPassKey)
                defaults.set(token.accessToken, forKey: Self.savedTokenKey)
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
        defaults.removeObject(forKey: Self.savedTokenKey)
        Task { await APIClient.shared.setToken(nil) }
    }
}
