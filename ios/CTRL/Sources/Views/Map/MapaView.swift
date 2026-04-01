import SwiftUI
import MapKit

struct MapaView: View {
    let dailyState: DailyStateManager
    let onObraSelected: (Obra) -> Void
    let onOperarioDropped: (String, String) -> Void

    // Centro de España por defecto
    @State private var position: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 40.0, longitude: -3.7),
            span: MKCoordinateSpan(latitudeDelta: 8, longitudeDelta: 8)
        )
    )

    var body: some View {
        Map(position: $position) {
            // Chinchetas de obras (azul)
            ForEach(dailyState.obras.filter { $0.coordinate != nil }) { obra in
                Annotation(
                    obraLabel(obra),
                    coordinate: obra.coordinate!
                ) {
                    ObraPin(
                        nombre: obra.nombre,
                        count: dailyState.operarioCount(for: obra.id)
                    )
                    .onTapGesture { onObraSelected(obra) }
                    .dropDestination(for: String.self) { items, _ in
                        if let operarioId = items.first {
                            onOperarioDropped(operarioId, obra.id)
                            return true
                        }
                        return false
                    }
                }
            }

            // Chinchetas de operarios sin obra (posición libre)
            ForEach(operariosLibres, id: \.asignacion.id) { item in
                Annotation(
                    item.operario.nombre,
                    coordinate: item.asignacion.coordinateLibre!
                ) {
                    OperarioPin(nombre: item.operario.nombre, isRuta: false)
                }
            }

            // Chinchetas de operarios en ruta (verde)
            ForEach(operariosRuta, id: \.asignacion.id) { item in
                if let firstObra = firstObraOfRuta(item.asignacion) {
                    Annotation(
                        "\(item.operario.nombre) (ruta)",
                        coordinate: firstObra
                    ) {
                        OperarioPin(nombre: item.operario.nombre, isRuta: true)
                    }
                }
            }
        }
        .mapStyle(.standard)
        .mapControls {
            MapCompass()
            MapScaleView()
        }
    }

    private func obraLabel(_ obra: Obra) -> String {
        let count = dailyState.operarioCount(for: obra.id)
        return count > 0 ? "\(obra.nombre) ×\(count)" : obra.nombre
    }

    private struct OperarioAsignacionPair {
        let operario: Operario
        let asignacion: Asignacion
    }

    private var operariosLibres: [OperarioAsignacionPair] {
        dailyState.asignaciones
            .filter { $0.activo && $0.obraId == nil && $0.coordinateLibre != nil && !$0.esRuta }
            .compactMap { asig in
                guard let op = dailyState.operarios.first(where: { $0.id == asig.operarioId }) else { return nil }
                return OperarioAsignacionPair(operario: op, asignacion: asig)
            }
    }

    private var operariosRuta: [OperarioAsignacionPair] {
        dailyState.asignaciones
            .filter { $0.activo && $0.esRuta }
            .compactMap { asig in
                guard let op = dailyState.operarios.first(where: { $0.id == asig.operarioId }) else { return nil }
                return OperarioAsignacionPair(operario: op, asignacion: asig)
            }
    }

    private func firstObraOfRuta(_ asig: Asignacion) -> CLLocationCoordinate2D? {
        guard let rutaIds = asig.obrasRuta, let firstId = rutaIds.first,
              let obra = dailyState.obras.first(where: { $0.id == firstId }) else { return nil }
        return obra.coordinate
    }
}

// MARK: - Chincheta de obra

struct ObraPin: View {
    let nombre: String
    let count: Int

    var body: some View {
        VStack(spacing: 2) {
            ZStack {
                Circle()
                    .fill(.blue)
                    .frame(width: 36, height: 36)

                Image(systemName: "building.2.fill")
                    .foregroundStyle(.white)
                    .font(.system(size: 16))
            }

            if count > 0 {
                Text("×\(count)")
                    .font(.caption2.bold())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 1)
                    .background(.blue.opacity(0.8), in: Capsule())
            }
        }
    }
}

// MARK: - Chincheta de operario

struct OperarioPin: View {
    let nombre: String
    let isRuta: Bool

    var body: some View {
        ZStack {
            Circle()
                .fill(isRuta ? .green : .brown)
                .frame(width: 30, height: 30)

            Image(systemName: isRuta ? "figure.walk" : "person.fill")
                .foregroundStyle(.white)
                .font(.system(size: 14))
        }
    }
}
