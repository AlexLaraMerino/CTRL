import SwiftUI

/// Gestiona el estado de autenticación de la app.
@Observable
final class AuthManager {
    var isAuthenticated = false
    var currentUser: String = ""
    var errorMessage: String?
    var isLoading = false

    func login(username: String, password: String) async {
        isLoading = true
        errorMessage = nil
        do {
            _ = try await APIClient.shared.login(username: username, password: password)
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
        Task { await APIClient.shared.setToken(nil) }
    }
}
