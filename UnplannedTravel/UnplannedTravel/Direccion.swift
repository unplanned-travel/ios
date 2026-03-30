import Foundation

struct Direccion: Codable, Equatable {
    var descripcion: String = ""
    var ciudad: String = ""
    var pais: String = ""

    var resumen: String {
        [descripcion, ciudad, pais].filter { !$0.isEmpty }.joined(separator: ", ")
    }

    var estaVacia: Bool { resumen.isEmpty }
}
