import SwiftUI

struct TopBar: View {
    let dateDisplay: String
    let onPrevDay: () -> Void
    let onNextDay: () -> Void
    let onToggleLeft: () -> Void
    let onShowObras: () -> Void
    let onShowOperarios: () -> Void
    let onShowHistorial: () -> Void
    let onShowSearch: () -> Void

    var body: some View {
        HStack {
            // Izquierda: botón calendario + búsqueda
            HStack(spacing: 12) {
                Button(action: onToggleLeft) {
                    Image(systemName: "calendar")
                        .font(.title2)
                }

                Button(action: onShowSearch) {
                    Image(systemName: "magnifyingglass")
                        .font(.title2)
                }
            }
            .padding(.leading)

            Spacer()

            // Centro: navegación de fecha
            HStack(spacing: 16) {
                Button(action: onPrevDay) {
                    Image(systemName: "chevron.left")
                        .font(.title3)
                }

                Text(dateDisplay)
                    .font(.headline)

                Button(action: onNextDay) {
                    Image(systemName: "chevron.right")
                        .font(.title3)
                }
            }

            Spacer()

            // Derecha: botones de paneles
            HStack(spacing: 12) {
                Button("Obras", action: onShowObras)
                    .buttonStyle(.bordered)

                Button("Operarios", action: onShowOperarios)
                    .buttonStyle(.bordered)

                Button(action: onShowHistorial) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.title2)
                }
            }
            .padding(.trailing)
        }
        .frame(height: 48)
        .background(.ultraThinMaterial)
    }
}
