import SwiftUI
import MapKit

struct MapaView: View {
    let dailyState: DailyStateManager
    let onObraSelected: (Obra) -> Void
    let onOperarioDropped: (String, String) -> Void
    @Binding var position: MapCameraPosition

    // Long-press state
    @State private var pinnedCoordinate: CLLocationCoordinate2D?
    @State private var showNewObraForm = false

    var body: some View {
        ZStack {
            MapReader { proxy in
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

                    // Pin temporal del long-press
                    if let coord = pinnedCoordinate {
                        Annotation("", coordinate: coord) {
                            VStack(spacing: 0) {
                                Image(systemName: "mappin.circle.fill")
                                    .font(.system(size: 40))
                                    .foregroundStyle(.red)
                                Image(systemName: "arrowtriangle.down.fill")
                                    .font(.system(size: 12))
                                    .foregroundStyle(.red)
                                    .offset(y: -4)
                            }
                        }
                    }
                }
                .mapStyle(.standard)
                .mapControls {
                    MapCompass()
                    MapScaleView()
                }
                .onLongPressGesture(minimumDuration: 0.5) { value in
                    if let coordinate = proxy.convert(value, from: .local) {
                        pinnedCoordinate = coordinate
                    }
                }
            }

            // Tarjeta de coordenadas al hacer long-press
            if let coord = pinnedCoordinate {
                VStack {
                    Spacer()

                    CoordinateCard(
                        coordinate: coord,
                        onCreateObra: {
                            showNewObraForm = true
                        },
                        onDismiss: {
                            pinnedCoordinate = nil
                        }
                    )
                    .padding(.bottom, 24)
                    .padding(.horizontal, 16)
                }
            }
        }
        .sheet(isPresented: $showNewObraForm) {
            if let coord = pinnedCoordinate {
                ObraFormView(
                    prefillLatitud: coord.latitude,
                    prefillLongitud: coord.longitude
                ) {
                    pinnedCoordinate = nil
                    Task { await dailyState.loadDay() }
                }
            }
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

// MARK: - Tarjeta de coordenadas

struct CoordinateCard: View {
    let coordinate: CLLocationCoordinate2D
    let onCreateObra: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Ubicación seleccionada")
                    .font(.subheadline.bold())

                Text(String(format: "%.5f, %.5f", coordinate.latitude, coordinate.longitude))
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                onCreateObra()
            } label: {
                Label("Crear obra aquí", systemImage: "building.2.fill")
                    .font(.subheadline.bold())
            }
            .buttonStyle(.borderedProminent)

            Button {
                onDismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .background(.ultraThickMaterial, in: RoundedRectangle(cornerRadius: 14))
        .shadow(radius: 8)
    }
}

// MARK: - Long press gesture on Map

extension View {
    func onLongPressGesture(minimumDuration: Double, perform: @escaping (CGPoint) -> Void) -> some View {
        self.gesture(
            LongPressGesture(minimumDuration: minimumDuration)
                .sequenced(before: DragGesture(minimumDistance: 0, coordinateSpace: .local))
                .onEnded { value in
                    if case .second(true, let drag?) = value {
                        perform(drag.location)
                    }
                }
        )
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
