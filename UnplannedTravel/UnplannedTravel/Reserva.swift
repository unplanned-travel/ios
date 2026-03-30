import Foundation

struct Reserva: Codable, Equatable {
    var referencia: String = ""
    var proveedor: String = ""
    var telefono: String = ""
    var email: String = ""
    var web: String = ""
    var notas: String = ""

    var estaVacia: Bool {
        referencia.isEmpty && proveedor.isEmpty && telefono.isEmpty
            && email.isEmpty && web.isEmpty && notas.isEmpty
    }
}
