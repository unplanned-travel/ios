import Foundation

struct Coste: Codable, Equatable {
    var previsto: Double = 0
    var extras: Double = 0
    var moneda: String = "EUR"

    var total: Double { previsto + extras }
}
