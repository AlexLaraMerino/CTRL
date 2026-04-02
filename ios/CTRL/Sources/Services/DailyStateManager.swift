import SwiftUI

/// Gestiona el estado diario: fecha seleccionada, obras, operarios y asignaciones del día.
@Observable
final class DailyStateManager {
    var selectedDate: Date = .now
    var obras: [Obra] = []
    var operarios: [Operario] = []
    var asignaciones: [Asignacion] = []
    var isLoading = false
    var error: String?

    var dateString: String {
        Self.dateFormatter.string(from: selectedDate)
    }

    var displayDate: String {
        Self.displayFormatter.string(from: selectedDate)
    }

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    private static let displayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "es_ES")
        f.dateFormat = "EEEE d 'de' MMMM yyyy"
        return f
    }()

    /// Carga todos los datos del día seleccionado.
    func loadDay() async {
        isLoading = true
        error = nil
        let fecha = dateString
        do {
            async let obrasTask = APIClient.shared.listObrasActivas(fecha: fecha)
            async let operariosTask = APIClient.shared.listOperarios()
            async let asignacionesTask = APIClient.shared.listAsignaciones(fecha: fecha)

            let (o, op, a) = try await (obrasTask, operariosTask, asignacionesTask)

            // Guardar en caché local
            await LocalCache.shared.cacheObras(o)
            await LocalCache.shared.cacheOperarios(op)
            await LocalCache.shared.cacheAsignaciones(a, fecha: fecha)

            await MainActor.run {
                self.obras = o
                self.operarios = op
                self.asignaciones = a
                self.isLoading = false
            }
        } catch {
            // Sin conexión: intentar cargar desde caché
            let cachedObras = await LocalCache.shared.loadObras()
            let cachedOps = await LocalCache.shared.loadOperarios()
            let cachedAsig = await LocalCache.shared.loadAsignaciones(fecha: fecha)

            await MainActor.run {
                if !cachedObras.isEmpty {
                    self.obras = cachedObras
                    self.operarios = cachedOps
                    self.asignaciones = cachedAsig
                    self.error = "Sin conexión — datos de la última sesión"
                } else {
                    self.error = "Sin conexión y sin datos en caché"
                }
                self.isLoading = false
            }
        }
    }

    func goToPreviousDay() {
        selectedDate = Calendar.current.date(byAdding: .day, value: -1, to: selectedDate) ?? selectedDate
        Task { await loadDay() }
    }

    func goToNextDay() {
        selectedDate = Calendar.current.date(byAdding: .day, value: 1, to: selectedDate) ?? selectedDate
        Task { await loadDay() }
    }

    func goToDate(_ date: Date) {
        selectedDate = date
        Task { await loadDay() }
    }

    /// Asigna un operario a una obra en el día seleccionado.
    func assignOperario(_ operarioId: String, toObra obraId: String) async {
        let body = AsignacionCreate(
            operarioId: operarioId,
            obraId: obraId,
            fecha: dateString,
            esRuta: false,
            obrasRuta: nil,
            latitudLibre: nil,
            longitudLibre: nil,
            notas: nil
        )
        do {
            _ = try await APIClient.shared.createAsignacion(body)
            await loadDay()
        } catch {
            await MainActor.run { self.error = error.localizedDescription }
        }
    }

    /// Copia la configuración de ayer al día seleccionado.
    func copyYesterday() async {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: selectedDate) ?? selectedDate
        let yesterdayStr = Self.dateFormatter.string(from: yesterday)
        do {
            _ = try await APIClient.shared.copiarDia(from: yesterdayStr, to: dateString)
            await loadDay()
        } catch {
            await MainActor.run { self.error = error.localizedDescription }
        }
    }

    /// Extiende las asignaciones del día al resto de la semana.
    func extendWeek() async {
        do {
            _ = try await APIClient.shared.extenderSemana(from: dateString)
            await loadDay()
        } catch {
            await MainActor.run { self.error = error.localizedDescription }
        }
    }

    /// Devuelve los operarios asignados a una obra en el día actual.
    func operariosInObra(_ obraId: String) -> [Operario] {
        let assignedIds = asignaciones
            .filter { $0.obraId == obraId && $0.activo }
            .map(\.operarioId)
        return operarios.filter { assignedIds.contains($0.id) }
    }

    /// Devuelve la cantidad de operarios asignados a una obra.
    func operarioCount(for obraId: String) -> Int {
        asignaciones.filter { $0.obraId == obraId && $0.activo }.count
    }

    /// Devuelve los operarios sin asignación activa hoy.
    func unassignedOperarios() -> [Operario] {
        let assignedIds = Set(asignaciones.filter(\.activo).map(\.operarioId))
        return operarios.filter { !assignedIds.contains($0.id) }
    }
}
