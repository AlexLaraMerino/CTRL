import Foundation

/// Caché local simple basada en ficheros JSON en Application Support.
/// Permite usar la app cuando no hay conexión al servidor.
actor LocalCache {
    static let shared = LocalCache()

    private let cacheDir: URL

    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        cacheDir = appSupport.appendingPathComponent("ctrl-cache", isDirectory: true)
        try? FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)
    }

    // MARK: - Guardar datos en caché

    func cacheObras(_ obras: [Obra]) {
        save(obras, filename: "obras.json")
    }

    func cacheOperarios(_ operarios: [Operario]) {
        save(operarios, filename: "operarios.json")
    }

    func cacheAsignaciones(_ asignaciones: [Asignacion], fecha: String) {
        save(asignaciones, filename: "asignaciones_\(fecha).json")
    }

    // MARK: - Leer datos de la caché

    func loadObras() -> [Obra] {
        load(filename: "obras.json") ?? []
    }

    func loadOperarios() -> [Operario] {
        load(filename: "operarios.json") ?? []
    }

    func loadAsignaciones(fecha: String) -> [Asignacion] {
        load(filename: "asignaciones_\(fecha).json") ?? []
    }

    // MARK: - Verificar si hay datos en caché

    func hasCache() -> Bool {
        FileManager.default.fileExists(atPath: cacheDir.appendingPathComponent("obras.json").path)
    }

    // MARK: - Limpiar caché antigua (más de 7 días)

    func cleanOldCache() {
        guard let files = try? FileManager.default.contentsOfDirectory(at: cacheDir, includingPropertiesForKeys: [.contentModificationDateKey]) else { return }
        let cutoff = Date().addingTimeInterval(-7 * 24 * 3600)
        for file in files {
            if let attrs = try? file.resourceValues(forKeys: [.contentModificationDateKey]),
               let date = attrs.contentModificationDate, date < cutoff {
                try? FileManager.default.removeItem(at: file)
            }
        }
    }

    // MARK: - Privado

    private func save<T: Encodable>(_ data: T, filename: String) {
        let url = cacheDir.appendingPathComponent(filename)
        guard let encoded = try? JSONEncoder().encode(data) else { return }
        try? encoded.write(to: url)
    }

    private func load<T: Decodable>(filename: String) -> T? {
        let url = cacheDir.appendingPathComponent(filename)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }
}
