import Foundation

struct Direccion: Codable, Equatable {
    var descripcion: String = ""        // Place name (e.g. "Museo del Prado")
    var direccionCompleta: String = ""  // Full street address (e.g. "Calle Ruiz de Alarcón 23, 28014 Madrid")
    var ciudad: String = ""
    var pais: String = ""
    var latitud: Double?
    var longitud: Double?

    var resumen: String {
        let partes = [descripcion, direccionCompleta.isEmpty ? ciudad : direccionCompleta, pais]
        return partes.filter { !$0.isEmpty }.joined(separator: ", ")
    }

    var estaVacia: Bool { descripcion.isEmpty && direccionCompleta.isEmpty && ciudad.isEmpty }

    var tieneCoordenadas: Bool { latitud != nil && longitud != nil }
}
