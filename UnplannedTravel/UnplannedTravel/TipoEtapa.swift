import Foundation

enum TipoEtapa: String, CaseIterable, Codable, Identifiable {
    case vuelo
    case hotel
    case coche, taxi, bus, tren, metro, barco
    case restaurante, bar, cafe
    case cine, teatro, concierto, vidaNocturna
    case visitaGuiada, museo, compras, reunion, deporte, actividad

    var id: String { rawValue }

    var nombre: String {
        NSLocalizedString("tipo.\(rawValue)", comment: "Stage type name")
    }

    var icono: String {
        switch self {
        case .vuelo:        return "airplane"
        case .hotel:        return "bed.double"
        case .coche:        return "car"
        case .taxi:         return "car.fill"
        case .bus:          return "bus"
        case .tren:         return "tram"
        case .metro:        return "tram.fill"
        case .barco:        return "ferry"
        case .restaurante:  return "fork.knife"
        case .bar:          return "wineglass"
        case .cafe:         return "cup.and.saucer"
        case .cine:         return "film"
        case .teatro:       return "theatermasks"
        case .concierto:    return "music.note"
        case .vidaNocturna: return "moon.stars"
        case .visitaGuiada: return "figure.walk"
        case .museo:        return "building.columns"
        case .compras:      return "bag"
        case .reunion:      return "person.2"
        case .deporte:      return "sportscourt"
        case .actividad:    return "star"
        }
    }

    enum Categoria: String, CaseIterable, Identifiable {
        case vuelos      = "vuelos"
        case alojamiento = "alojamiento"
        case transporte  = "transporte"
        case foodAndDrink = "foodAndDrink"
        case ocio        = "ocio"
        case actividades = "actividades"

        var id: String { rawValue }

        var titulo: String {
            NSLocalizedString("categoria.\(rawValue)", comment: "Stage category name")
        }

        var tipos: [TipoEtapa] {
            TipoEtapa.allCases.filter { $0.categoria == self }
        }
    }

    var categoria: Categoria {
        switch self {
        case .vuelo:
            return .vuelos
        case .hotel:
            return .alojamiento
        case .coche, .taxi, .bus, .tren, .metro, .barco:
            return .transporte
        case .restaurante, .bar, .cafe:
            return .foodAndDrink
        case .cine, .teatro, .concierto, .vidaNocturna:
            return .ocio
        case .visitaGuiada, .museo, .compras, .reunion, .deporte, .actividad:
            return .actividades
        }
    }

    var esTransporte: Bool {
        switch self {
        case .vuelo, .coche, .taxi, .bus, .tren, .metro, .barco:
            return true
        default:
            return false
        }
    }

    var tieneReserva: Bool {
        switch self {
        case .vuelo, .hotel, .tren, .barco, .bus:
            return true
        default:
            return false
        }
    }

    /// Localized placeholder label for the main name/title field.
    var etiquetaNombre: String {
        switch self {
        case .cine, .teatro, .concierto, .vidaNocturna,
             .visitaGuiada, .museo, .reunion, .deporte, .actividad:
            return NSLocalizedString("field.title", value: "Title", comment: "Field label for event title")
        default:
            return NSLocalizedString("field.name", value: "Name", comment: "Field label for place or entity name")
        }
    }
}
