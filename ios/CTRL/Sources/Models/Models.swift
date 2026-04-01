import Foundation
import CoreLocation

// MARK: - Obra

struct Obra: Codable, Identifiable, Hashable {
    let id: String
    var nombre: String
    var direccion: String?
    var latitud: Double?
    var longitud: Double?
    var estado: String
    var tiposInstalacion: [String]?
    var carpetaServidor: String?
    var notas: String?
    var fechaInicio: String?
    var fechaFinPrevista: String?
    var createdAt: String?
    var updatedAt: String?

    var coordinate: CLLocationCoordinate2D? {
        guard let lat = latitud, let lng = longitud else { return nil }
        return CLLocationCoordinate2D(latitude: lat, longitude: lng)
    }

    enum CodingKeys: String, CodingKey {
        case id, nombre, direccion, latitud, longitud, estado
        case tiposInstalacion = "tipos_instalacion"
        case carpetaServidor = "carpeta_servidor"
        case notas
        case fechaInicio = "fecha_inicio"
        case fechaFinPrevista = "fecha_fin_prevista"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

// MARK: - Operario

struct Operario: Codable, Identifiable, Hashable {
    let id: String
    var nombre: String
    var telefono: String?
    var especialidades: [String]?
    var activo: Bool
    var notas: String?
    var createdAt: String?

    /// Iniciales para avatar
    var initials: String {
        let parts = nombre.split(separator: " ")
        if parts.count >= 2 {
            return String(parts[0].prefix(1) + parts[1].prefix(1)).uppercased()
        }
        return String(nombre.prefix(2)).uppercased()
    }

    enum CodingKeys: String, CodingKey {
        case id, nombre, telefono, especialidades, activo, notas
        case createdAt = "created_at"
    }
}

// MARK: - Asignación

struct Asignacion: Codable, Identifiable, Hashable {
    let id: String
    var operarioId: String
    var obraId: String?
    var fecha: String
    var esRuta: Bool
    var obrasRuta: [String]?
    var latitudLibre: Double?
    var longitudLibre: Double?
    var notas: String?
    var createdBy: String?
    var activo: Bool
    var createdAt: String?

    var coordinateLibre: CLLocationCoordinate2D? {
        guard let lat = latitudLibre, let lng = longitudLibre else { return nil }
        return CLLocationCoordinate2D(latitude: lat, longitude: lng)
    }

    enum CodingKeys: String, CodingKey {
        case id, fecha, notas, activo
        case operarioId = "operario_id"
        case obraId = "obra_id"
        case esRuta = "es_ruta"
        case obrasRuta = "obras_ruta"
        case latitudLibre = "latitud_libre"
        case longitudLibre = "longitud_libre"
        case createdBy = "created_by"
        case createdAt = "created_at"
    }
}

// MARK: - Plano

struct Plano: Codable, Identifiable, Hashable {
    let id: String
    var obraId: String
    var nombre: String
    var rutaOriginal: String
    var rutaAnotada: String?
    var version: Int
    var anotadoPor: String?
    var anotadoEn: String?
    var createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id, nombre, version
        case obraId = "obra_id"
        case rutaOriginal = "ruta_original"
        case rutaAnotada = "ruta_anotada"
        case anotadoPor = "anotado_por"
        case anotadoEn = "anotado_en"
        case createdAt = "created_at"
    }
}

// MARK: - Historial

struct HistorialEntry: Codable, Identifiable, Hashable {
    let id: String
    var timestamp: String
    var usuario: String
    var tipoAccion: String
    var entidadTipo: String
    var entidadId: String
    var descripcion: String
    var datosAnteriores: String?
    var datosNuevos: String?

    enum CodingKeys: String, CodingKey {
        case id, timestamp, usuario, descripcion
        case tipoAccion = "tipo_accion"
        case entidadTipo = "entidad_tipo"
        case entidadId = "entidad_id"
        case datosAnteriores = "datos_anteriores"
        case datosNuevos = "datos_nuevos"
    }
}

// MARK: - Auth

struct LoginRequest: Codable {
    let username: String
    let password: String
}

struct TokenResponse: Codable {
    let accessToken: String
    let tokenType: String

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case tokenType = "token_type"
    }
}

// MARK: - Requests

struct AsignacionCreate: Codable {
    let operarioId: String
    let obraId: String?
    let fecha: String
    let esRuta: Bool
    let obrasRuta: [String]?
    let latitudLibre: Double?
    let longitudLibre: Double?
    let notas: String?

    enum CodingKeys: String, CodingKey {
        case fecha, notas
        case operarioId = "operario_id"
        case obraId = "obra_id"
        case esRuta = "es_ruta"
        case obrasRuta = "obras_ruta"
        case latitudLibre = "latitud_libre"
        case longitudLibre = "longitud_libre"
    }
}

struct CopiarDiaRequest: Codable {
    let fechaOrigen: String
    let fechaDestino: String

    enum CodingKeys: String, CodingKey {
        case fechaOrigen = "fecha_origen"
        case fechaDestino = "fecha_destino"
    }
}

struct ExtenderSemanaRequest: Codable {
    let fechaOrigen: String

    enum CodingKeys: String, CodingKey {
        case fechaOrigen = "fecha_origen"
    }
}
