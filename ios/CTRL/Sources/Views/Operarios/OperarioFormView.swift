import SwiftUI

struct OperarioFormView: View {
    var existingOperario: Operario?
    let onSaved: () -> Void

    @State private var nombre = ""
    @State private var telefono = ""
    @State private var espFontaneria = false
    @State private var espCPI = false
    @State private var espGas = false
    @State private var activo = true
    @State private var notas = ""
    @State private var isSaving = false
    @State private var error: String?
    @Environment(\.dismiss) private var dismiss

    private var isEditing: Bool { existingOperario != nil }

    var body: some View {
        NavigationStack {
            Form {
                Section("Datos personales") {
                    TextField("Nombre completo", text: $nombre)
                    TextField("Teléfono", text: $telefono)
                        .keyboardType(.phonePad)
                }

                Section("Especialidades") {
                    Toggle("Fontanería", isOn: $espFontaneria)
                    Toggle("CPI", isOn: $espCPI)
                    Toggle("Gas", isOn: $espGas)
                }

                Section {
                    Toggle("Activo", isOn: $activo)
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
            .navigationTitle(isEditing ? "Editar operario" : "Nuevo operario")
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
        guard let op = existingOperario else { return }
        nombre = op.nombre
        telefono = op.telefono ?? ""
        if let esp = op.especialidades {
            espFontaneria = esp.contains("fontanería")
            espCPI = esp.contains("CPI")
            espGas = esp.contains("gas")
        }
        activo = op.activo
        notas = op.notas ?? ""
    }

    private func save() async {
        isSaving = true
        error = nil

        var especialidades: [String] = []
        if espFontaneria { especialidades.append("fontanería") }
        if espCPI { especialidades.append("CPI") }
        if espGas { especialidades.append("gas") }

        var data: [String: Any] = [
            "nombre": nombre,
            "activo": activo,
        ]
        if !telefono.isEmpty { data["telefono"] = telefono }
        if !especialidades.isEmpty { data["especialidades"] = especialidades }
        if !notas.isEmpty { data["notas"] = notas }

        do {
            if let existing = existingOperario {
                _ = try await APIClient.shared.updateOperario(id: existing.id, data: data)
            } else {
                _ = try await APIClient.shared.createOperario(data)
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
