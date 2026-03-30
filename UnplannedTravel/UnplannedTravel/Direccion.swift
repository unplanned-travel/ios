import Foundation

struct Direccion: Codable, Equatable {
    var descripcion: String = ""
    var ciudad: String = ""
    var pais: String = ""
    var latitud: Double?
    var longitud: Double?

    var resumen: String {
        [descripcion, ciudad, pais].filter { !$0.isEmpty }.joined(separator: ", ")
    }

    var estaVacia: Bool { resumen.isEmpty }

    var tieneCoordenadas: Bool { latitud != nil && longitud != nil }
}
