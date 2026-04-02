import SwiftUI
import MapKit

/// ViewModel que gestiona la animación de un operario recorriendo su ruta.
@Observable
final class RouteAnimator {
    var currentPosition: CLLocationCoordinate2D
    private var currentIndex = 0
    private var progress: CGFloat = 0
    private var timer: Timer?
    private let coordinates: [CLLocationCoordinate2D]
    private let stepDuration: TimeInterval = 3.0
    private let tickInterval: TimeInterval = 0.05

    init(coordinates: [CLLocationCoordinate2D]) {
        self.coordinates = coordinates
        self.currentPosition = coordinates.first ?? CLLocationCoordinate2D()
    }

    func start() {
        guard coordinates.count >= 2, timer == nil else { return }
        timer = Timer.scheduledTimer(withTimeInterval: tickInterval, repeats: true) { [weak self] _ in
            self?.tick()
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func tick() {
        let tickProgress = CGFloat(tickInterval / stepDuration)
        progress += tickProgress

        if progress >= 1.0 {
            progress = 0
            currentIndex = (currentIndex + 1) % coordinates.count
        }

        let from = coordinates[currentIndex]
        let to = coordinates[(currentIndex + 1) % coordinates.count]

        let lat = from.latitude + (to.latitude - from.latitude) * Double(progress)
        let lng = from.longitude + (to.longitude - from.longitude) * Double(progress)
        currentPosition = CLLocationCoordinate2D(latitude: lat, longitude: lng)
    }
}
