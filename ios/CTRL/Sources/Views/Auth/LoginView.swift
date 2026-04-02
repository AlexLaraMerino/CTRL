import SwiftUI

struct LoginView: View {
    @Environment(AuthManager.self) private var auth
    @State private var username = ""
    @State private var password = ""
    @State private var rememberSession = false

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // Logo y título
            VStack(spacing: 12) {
                Image(systemName: "map.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(.blue)

                Text("CTRL")
                    .font(.system(size: 48, weight: .bold))

                Text("Gestión de obras y operarios")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            // Formulario
            VStack(spacing: 16) {
                TextField("Usuario", text: $username)
                    .textFieldStyle(.roundedBorder)
                    .textContentType(.username)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)

                SecureField("Contraseña", text: $password)
                    .textFieldStyle(.roundedBorder)
                    .textContentType(.password)

                Toggle("Mantener sesión iniciada", isOn: $rememberSession)
                    .font(.subheadline)

                if let error = auth.errorMessage {
                    Text(error)
                        .foregroundStyle(.red)
                        .font(.caption)
                }

                Button {
                    Task { await auth.login(username: username, password: password, remember: rememberSession) }
                } label: {
                    if auth.isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Text("Entrar")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(username.isEmpty || password.isEmpty || auth.isLoading)
            }
            .frame(maxWidth: 320)

            Spacer()
            Spacer()
        }
        .padding()
    }
}
