import Foundation
import SwiftData

@Model final class Etapa {
    // Stored as String so the enum can evolve without migration issues.
    var tipoRaw: String
    var fechaInicio: Date
    /// Checkout (hotel), arrival (transport/vuelo), end (events). Optional for point-in-time etapas.
    var fechaFin: Date?

    /// Primary label: hotel name, restaurant, venue, event title, activity name, etc.
    var nombre: String?
    var notas: String?
    var coste: Coste?

    // Origin / destination — used by Vuelo and all transport types.
    var origen: Direccion?
    var destino: Direccion?

    // Venue location — used by Hotel, Food & Drink, Ocio, and Actividad types.
    var direccion: Direccion?

    // Booking details — used by Hotel, Vuelo, Tren, Barco, Bus.
    var reserva: Reserva?

    // Coche / Barco option.
    var rutaCircular: Bool?

    var plan: Plan?

    var tipo: TipoEtapa {
        get { TipoEtapa(rawValue: tipoRaw) ?? .actividad }
        set { tipoRaw = newValue.rawValue }
    }

    init(tipo: TipoEtapa, fechaInicio: Date = Date()) {
        self.tipoRaw = tipo.rawValue
        self.fechaInicio = fechaInicio
    }

    /// True when the etapa has at least one geocoded location to show on a map.
    var tieneUbicacion: Bool {
        if tipo.esTransporte {
            return origen?.tieneCoordenadas == true || destino?.tieneCoordenadas == true
        }
        return direccion?.tieneCoordenadas == true
    }

    /// Human-readable label shown in list rows.
    var etiqueta: String {
        switch tipo {
        case .vuelo, .coche, .taxi, .bus, .tren, .metro, .barco:
            let o = origen.flatMap { $0.estaVacia ? nil : ($0.descripcion.isEmpty ? $0.ciudad : $0.descripcion) }
            let d = destino.flatMap { $0.estaVacia ? nil : ($0.descripcion.isEmpty ? $0.ciudad : $0.descripcion) }
            if let o, let d { return "\(o) → \(d)" }
            if let o { return "\(o) →" }
            return nombre ?? tipo.nombre
        default:
            return nombre.flatMap { $0.isEmpty ? nil : $0 } ?? tipo.nombre
        }
    }
}
