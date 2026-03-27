import SwiftUI

struct LoginView: View {
    @EnvironmentObject private var store: DailyBoardStore
    @State private var pin4 = ""
    @State private var rememberUser = true
    @State private var showError = false

    var body: some View {
        ZStack {
            Color.ctrlBackground
                .ignoresSafeArea()

            VStack(spacing: 24) {
                VStack(spacing: 10) {
                    Text("CTRL")
                        .font(.system(size: 42, weight: .black, design: .rounded))
                        .foregroundStyle(.white)

                    Text("Acceso rápido por código")
                        .font(.system(size: 18, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.ctrlMuted)
                }

                VStack(alignment: .leading, spacing: 16) {
                    Text("Código de 4 cifras")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    SecureField("0000", text: $pin4)
                        .keyboardType(.numberPad)
                        .textContentType(.oneTimeCode)
                        .font(.system(size: 30, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 16)
                        .background(Color.ctrlPanelSoft, in: RoundedRectangle(cornerRadius: 20, style: .continuous))

                    Toggle("Recordar usuario en este iPad", isOn: $rememberUser)
                        .font(.system(size: 17, weight: .medium, design: .rounded))
                        .foregroundStyle(.white)
                        .tint(Color.ctrlAccent)

                    Button("Entrar") {
                        let success = store.login(pin4: pin4, rememberUser: rememberUser)
                        showError = !success
                        if success {
                            pin4 = ""
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color.ctrlAccent)
                    .font(.system(size: 18, weight: .bold, design: .rounded))

                    if showError {
                        Text("Código no válido")
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundStyle(.red.opacity(0.9))
                    }
                }
                .padding(24)
                .frame(width: 420)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 30, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 30, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )

            }
            .padding(24)
        }
    }
}
