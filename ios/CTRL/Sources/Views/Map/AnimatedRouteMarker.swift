import SwiftUI
import MapKit

/// Marcador animado que se mueve entre las coordenadas de una ruta.
/// Usa un Timer para interpolar suavemente entre puntos.
struct AnimatedRouteMarker: View {
    let operarioName: String
    let routeCoordinates: [CLLocationCoordinate2D]

    @State private var currentIndex = 0
    @State private var progress: CGFloat = 0
    @State private var currentPosition: CLLocationCoordinate2D

    private let stepDuration: TimeInterval = 3.0 // segundos entre puntos
    private let tickInterval: TimeInterval = 0.05 // 20fps de interpolación

    init(operarioName: String, routeCoordinates: [CLLocationCoordinate2D]) {
        self.operarioName = operarioName
        self.routeCoordinates = routeCoordinates
        self._currentPosition = State(initialValue: routeCoordinates.first ?? CLLocationCoordinate2D())
    }

    var body: some View {
        if routeCoordinates.count >= 2 {
            // Línea de ruta discontinua
            MapPolyline(coordinates: routeCoordinates + [routeCoordinates[0]]) // bucle cerrado
                .stroke(.green.opacity(0.6), style: StrokeStyle(lineWidth: 2, dash: [8, 6]))

            // Marcador animado
            Annotation(operarioName, coordinate: currentPosition) {
                VStack(spacing: 2) {
                    ZStack {
                        Circle()
                            .fill(.green)
                            .frame(width: 32, height: 32)
                            .shadow(color: .green.opacity(0.5), radius: 6)

                        Image(systemName: "figure.walk")
                            .foregroundStyle(.white)
                            .font(.system(size: 14))
                    }

                    Text(operarioName)
                        .font(.caption2.bold())
                        .padding(.horizontal, 6)
                        .padding(.vertical, 1)
                        .background(.green.opacity(0.8), in: Capsule())
                        .foregroundStyle(.white)
                }
            }
            .annotationTitles(.hidden)
            .onAppear { startAnimation() }
        }
    }

    private func startAnimation() {
        Timer.scheduledTimer(withTimeInterval: tickInterval, repeats: true) { _ in
            let tickProgress = CGFloat(tickInterval / stepDuration)

            progress += tickProgress

            if progress >= 1.0 {
                progress = 0
                currentIndex = (currentIndex + 1) % routeCoordinates.count
            }

            let from = routeCoordinates[currentIndex]
            let to = routeCoordinates[(currentIndex + 1) % routeCoordinates.count]

            // Interpolación lineal
            let lat = from.latitude + (to.latitude - from.latitude) * Double(progress)
            let lng = from.longitude + (to.longitude - from.longitude) * Double(progress)

            withAnimation(.linear(duration: tickInterval)) {
                currentPosition = CLLocationCoordinate2D(latitude: lat, longitude: lng)
            }
        }
    }
}
