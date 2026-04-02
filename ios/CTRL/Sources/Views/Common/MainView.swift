import SwiftUI
import MapKit

struct MainView: View {
    @Environment(AuthManager.self) private var auth
    @State private var dailyState = DailyStateManager()
    @State private var showLeftPanel = false
    @State private var showRightPanel = false
    @State private var rightPanelTab: RightPanelTab = .obras
    @State private var showHistorial = false
    @State private var showSearch = false
    @State private var selectedObra: Obra?
    @State private var selectedOperario: Operario?
    @State private var mapPosition: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 40.0, longitude: -3.7),
            span: MKCoordinateSpan(latitudeDelta: 8, longitudeDelta: 8)
        )
    )

    enum RightPanelTab {
        case obras, operarios
    }

    var body: some View {
        ZStack {
            // Mapa central (ocupa todo)
            MapaView(
                dailyState: dailyState,
                onObraSelected: { obra in selectedObra = obra },
                onOperarioDropped: { operarioId, obraId in
                    Task { await dailyState.assignOperario(operarioId, toObra: obraId) }
                },
                position: $mapPosition
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // Barra superior
                TopBar(
                    dateDisplay: dailyState.displayDate.capitalized,
                    onPrevDay: { dailyState.goToPreviousDay() },
                    onNextDay: { dailyState.goToNextDay() },
                    onToggleLeft: { showLeftPanel.toggle() },
                    onShowObras: {
                        rightPanelTab = .obras
                        showRightPanel = true
                    },
                    onShowOperarios: {
                        rightPanelTab = .operarios
                        showRightPanel = true
                    },
                    onShowHistorial: { showHistorial = true },
                    onShowSearch: { showSearch = true }
                )

                Spacer()
            }

            // Panel izquierdo — Calendario
            if showLeftPanel {
                HStack(spacing: 0) {
                    CalendarPanel(
                        dailyState: dailyState,
                        onClose: { showLeftPanel = false }
                    )
                    .frame(width: 320)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .shadow(radius: 8)
                    .padding(.leading, 8)
                    .padding(.top, 56)

                    Spacer()
                }
            }

            // Panel derecho — Obras / Operarios
            if showRightPanel {
                HStack(spacing: 0) {
                    Spacer()

                    RightPanel(
                        tab: $rightPanelTab,
                        dailyState: dailyState,
                        onClose: { showRightPanel = false },
                        onObraSelected: { obra in selectedObra = obra },
                        onOperarioSelected: { op in selectedOperario = op }
                    )
                    .frame(width: 340)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .shadow(radius: 8)
                    .padding(.trailing, 8)
                    .padding(.top, 56)
                }
            }
        }
        .sheet(item: $selectedObra) { obra in
            ObraDetailView(obra: obra, dailyState: dailyState)
        }
        .sheet(item: $selectedOperario) { operario in
            OperarioDetailView(operario: operario, dailyState: dailyState)
        }
        .sheet(isPresented: $showHistorial) {
            HistorialView()
        }
        .sheet(isPresented: $showSearch) {
            SearchView(
                dailyState: dailyState,
                onObraSelected: { obra in selectedObra = obra },
                onOperarioSelected: { op in selectedOperario = op },
                onCenterMap: { coord in
                    withAnimation {
                        mapPosition = .region(MKCoordinateRegion(
                            center: coord,
                            span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
                        ))
                    }
                }
            )
        }
        .task {
            await dailyState.loadDay()
        }
    }
}
