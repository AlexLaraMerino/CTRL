import SwiftUI

struct ObraFormView: View {
    var existingObra: Obra?
    let onSaved: () -> Void

    @State private var nombre = ""
    @State private var direccion = ""
    @State private var latitud = ""
    @State private var longitud = ""
    @State private var estado = "activa"
    @State private var tipoFontaneria = false
    @State private var tipoCPI = false
    @State private var tipoGas = false
    @State private var notas = ""
    @State private var fechaInicio = Date()
    @State private var fechaFinPrevista = Date()
    @State private var useFechaInicio = false
    @State private var useFechaFin = false
    @State private var isSaving = false
    @State private var error: String?
    @Environment(\.dismiss) private var dismiss

    private var isEditing: Bool { existingObra != nil }

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    var body: some View {
        NavigationStack {
            Form {
                Section("Datos principales") {
                    TextField("Nombre de la obra", text: $nombre)
                    TextField("Dirección", text: $direccion)
                }

                Section("Coordenadas") {
                    TextField("Latitud (ej: 40.4168)", text: $latitud)
                        .keyboardType(.decimalPad)
                    TextField("Longitud (ej: -3.7038)", text: $longitud)
                        .keyboardType(.decimalPad)
                }

                Section("Estado") {
                    Picker("Estado", selection: $estado) {
                        Text("Activa").tag("activa")
                        Text("Pausada").tag("pausada")
                        Text("Finalizada").tag("finalizada")
                    }
                    .pickerStyle(.segmented)
                }

                Section("Tipos de instalación") {
                    Toggle("Fontanería", isOn: $tipoFontaneria)
                    Toggle("CPI", isOn: $tipoCPI)
                    Toggle("Gas", isOn: $tipoGas)
                }

                Section("Fechas") {
                    Toggle("Fecha de inicio", isOn: $useFechaInicio)
                    if useFechaInicio {
                        DatePicker("Inicio", selection: $fechaInicio, displayedComponents: .date)
                    }
                    Toggle("Fecha fin prevista", isOn: $useFechaFin)
                    if useFechaFin {
                        DatePicker("Fin previsto", selection: $fechaFinPrevista, displayedComponents: .date)
                    }
                }

                Section("Notas") {
                    TextEditor(text: $notas)
                        .frame(minHeight: 80)
                }

                if let error {
                    Section {
                        Text(error)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle(isEditing ? "Editar obra" : "Nueva obra")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(isEditing ? "Guardar" : "Crear") {
                        Task { await save() }
                    }
                    .disabled(nombre.isEmpty || isSaving)
                    .bold()
                }
            }
            .onAppear { loadExisting() }
        }
    }

    private func loadExisting() {
        guard let obra = existingObra else { return }
        nombre = obra.nombre
        direccion = obra.direccion ?? ""
        if let lat = obra.latitud { latitud = String(lat) }
        if let lng = obra.longitud { longitud = String(lng) }
        estado = obra.estado
        if let tipos = obra.tiposInstalacion {
            tipoFontaneria = tipos.contains("fontanería")
            tipoCPI = tipos.contains("CPI")
            tipoGas = tipos.contains("gas")
        }
        notas = obra.notas ?? ""
        if let fi = obra.fechaInicio {
            useFechaInicio = true
            if let date = Self.dateFormatter.date(from: fi) { fechaInicio = date }
        }
        if let ff = obra.fechaFinPrevista {
            useFechaFin = true
            if let date = Self.dateFormatter.date(from: ff) { fechaFinPrevista = date }
        }
    }

    private func save() async {
        isSaving = true
        error = nil

        var tipos: [String] = []
        if tipoFontaneria { tipos.append("fontanería") }
        if tipoCPI { tipos.append("CPI") }
        if tipoGas { tipos.append("gas") }

        var data: [String: Any] = [
            "nombre": nombre,
            "estado": estado,
        ]
        if !direccion.isEmpty { data["direccion"] = direccion }
        if let lat = Double(latitud) { data["latitud"] = lat }
        if let lng = Double(longitud) { data["longitud"] = lng }
        if !tipos.isEmpty { data["tipos_instalacion"] = tipos }
        if !notas.isEmpty { data["notas"] = notas }
        if useFechaInicio { data["fecha_inicio"] = Self.dateFormatter.string(from: fechaInicio) }
        if useFechaFin { data["fecha_fin_prevista"] = Self.dateFormatter.string(from: fechaFinPrevista) }

        do {
            if let existing = existingObra {
                _ = try await APIClient.shared.updateObra(id: existing.id, data: data)
            } else {
                _ = try await APIClient.shared.createObra(data)
            }
            await MainActor.run {
                onSaved()
                dismiss()
            }
        } catch {
            await MainActor.run {
                self.error = error.localizedDescription
                isSaving = false
            }
        }
    }
}
