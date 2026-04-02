import Foundation

/// Cliente HTTP para la API REST de CTRL. Actor para seguridad concurrente.
actor APIClient {
    static let shared = APIClient()

    // Configurable: cambiar en producción
    private var baseURL = "http://localhost:8000"
    private var token: String?

    func getToken() -> String? { token }

    func configure(baseURL: String) {
        self.baseURL = baseURL
    }

    func setToken(_ token: String?) {
        self.token = token
    }

    // MARK: - Auth

    func login(username: String, password: String) async throws -> TokenResponse {
        let body = LoginRequest(username: username, password: password)
        let response: TokenResponse = try await post("/auth/login", body: body, authenticated: false)
        self.token = response.accessToken
        return response
    }

    // MARK: - Obras

    func listObras(estado: String? = nil) async throws -> [Obra] {
        var path = "/obras"
        if let estado { path += "?estado=\(estado)" }
        return try await get(path)
    }

    func getObra(id: String) async throws -> Obra {
        return try await get("/obras/\(id)")
    }

    func createObra(_ data: [String: Any]) async throws -> Obra {
        return try await postJSON("/obras", json: data)
    }

    func updateObra(id: String, data: [String: Any]) async throws -> Obra {
        return try await patchJSON("/obras/\(id)", json: data)
    }

    func listObrasActivas(fecha: String? = nil) async throws -> [Obra] {
        var path = "/obras/activas"
        if let fecha { path += "?fecha=\(fecha)" }
        return try await get(path)
    }

    func listObraOperarios(obraId: String, fecha: String) async throws -> [Operario] {
        return try await get("/obras/\(obraId)/operarios?fecha=\(fecha)")
    }

    // MARK: - Operarios

    func listOperarios() async throws -> [Operario] {
        return try await get("/operarios")
    }

    func getOperario(id: String) async throws -> Operario {
        return try await get("/operarios/\(id)")
    }

    func createOperario(_ data: [String: Any]) async throws -> Operario {
        return try await postJSON("/operarios", json: data)
    }

    func updateOperario(id: String, data: [String: Any]) async throws -> Operario {
        return try await patchJSON("/operarios/\(id)", json: data)
    }

    func listOperarioAsignaciones(operarioId: String, desde: String? = nil, hasta: String? = nil) async throws -> [Asignacion] {
        var path = "/operarios/\(operarioId)/asignaciones"
        var params: [String] = []
        if let desde { params.append("desde=\(desde)") }
        if let hasta { params.append("hasta=\(hasta)") }
        if !params.isEmpty { path += "?" + params.joined(separator: "&") }
        return try await get(path)
    }

    // MARK: - Asignaciones

    func listAsignaciones(fecha: String) async throws -> [Asignacion] {
        return try await get("/asignaciones?fecha=\(fecha)")
    }

    func createAsignacion(_ body: AsignacionCreate) async throws -> Asignacion {
        return try await post("/asignaciones", body: body)
    }

    func deleteAsignacion(id: String) async throws {
        try await delete("/asignaciones/\(id)")
    }

    func copiarDia(from origen: String, to destino: String) async throws -> [Asignacion] {
        let body = CopiarDiaRequest(fechaOrigen: origen, fechaDestino: destino)
        return try await post("/asignaciones/copiar-dia", body: body)
    }

    func extenderSemana(from fecha: String) async throws -> [Asignacion] {
        let body = ExtenderSemanaRequest(fechaOrigen: fecha)
        return try await post("/asignaciones/extender-semana", body: body)
    }

    // MARK: - Planos

    func listPlanos(obraId: String) async throws -> [Plano] {
        return try await get("/obras/\(obraId)/planos")
    }

    func downloadPlanoURL(planoId: String) -> URL? {
        URL(string: "\(baseURL)/planos/\(planoId)")
    }

    func downloadPlanoAnotadoURL(planoId: String) -> URL? {
        URL(string: "\(baseURL)/planos/\(planoId)/anotado")
    }

    func uploadPlano(obraId: String, fileData: Data, filename: String) async throws -> Plano {
        return try await uploadMultipart("/obras/\(obraId)/planos", fileData: fileData, filename: filename)
    }

    func uploadAnotacion(planoId: String, pdfData: Data) async throws -> Plano {
        return try await uploadMultipart("/planos/\(planoId)/anotacion", fileData: pdfData, filename: "anotacion.pdf")
    }

    // MARK: - Historial

    func listHistorial(fecha: String? = nil, tipo: String? = nil, limit: Int = 50) async throws -> [HistorialEntry] {
        var params: [String] = []
        if let fecha { params.append("fecha=\(fecha)") }
        if let tipo { params.append("tipo=\(tipo)") }
        params.append("limit=\(limit)")
        return try await get("/historial?" + params.joined(separator: "&"))
    }

    func historialObra(obraId: String) async throws -> [HistorialEntry] {
        return try await get("/historial/obra/\(obraId)")
    }

    func historialOperario(operarioId: String) async throws -> [HistorialEntry] {
        return try await get("/historial/operario/\(operarioId)")
    }

    // MARK: - HTTP genérico

    private func get<T: Decodable>(_ path: String) async throws -> T {
        let request = try buildRequest(path, method: "GET")
        let (data, response) = try await URLSession.shared.data(for: request)
        try checkResponse(response)
        return try JSONDecoder().decode(T.self, from: data)
    }

    private func post<B: Encodable, T: Decodable>(_ path: String, body: B, authenticated: Bool = true) async throws -> T {
        var request = try buildRequest(path, method: "POST", authenticated: authenticated)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)
        let (data, response) = try await URLSession.shared.data(for: request)
        try checkResponse(response)
        return try JSONDecoder().decode(T.self, from: data)
    }

    private func postJSON<T: Decodable>(_ path: String, json: [String: Any]) async throws -> T {
        var request = try buildRequest(path, method: "POST")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: json)
        let (data, response) = try await URLSession.shared.data(for: request)
        try checkResponse(response)
        return try JSONDecoder().decode(T.self, from: data)
    }

    private func patchJSON<T: Decodable>(_ path: String, json: [String: Any]) async throws -> T {
        var request = try buildRequest(path, method: "PATCH")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: json)
        let (data, response) = try await URLSession.shared.data(for: request)
        try checkResponse(response)
        return try JSONDecoder().decode(T.self, from: data)
    }

    private func delete(_ path: String) async throws {
        let request = try buildRequest(path, method: "DELETE")
        let (_, response) = try await URLSession.shared.data(for: request)
        try checkResponse(response)
    }

    private func uploadMultipart<T: Decodable>(_ path: String, fileData: Data, filename: String) async throws -> T {
        var request = try buildRequest(path, method: "POST")
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: application/pdf\r\n\r\n".data(using: .utf8)!)
        body.append(fileData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = body

        let (data, response) = try await URLSession.shared.data(for: request)
        try checkResponse(response)
        return try JSONDecoder().decode(T.self, from: data)
    }

    private func buildRequest(_ path: String, method: String, authenticated: Bool = true) throws -> URLRequest {
        guard let url = URL(string: baseURL + path) else {
            throw APIError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = method
        if authenticated, let token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        return request
    }

    private func checkResponse(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        guard (200...299).contains(http.statusCode) else {
            throw APIError.httpError(http.statusCode)
        }
    }
}

enum APIError: LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(Int)

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "URL inválida"
        case .invalidResponse: return "Respuesta inválida del servidor"
        case .httpError(let code): return "Error HTTP \(code)"
        }
    }
}
