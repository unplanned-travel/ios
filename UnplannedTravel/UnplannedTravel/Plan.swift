import Foundation
import SwiftData

@Model final class Plan {
    var titulo: String
    var fechaInicio: Date?
    var fechaFin: Date?
    var notas: String?

    @Relationship(deleteRule: .cascade, inverse: \Etapa.plan)
    var etapas: [Etapa] = []

    init(titulo: String = "", fechaInicio: Date? = nil, fechaFin: Date? = nil, notas: String? = nil) {
        self.titulo = titulo
        self.fechaInicio = fechaInicio
        self.fechaFin = fechaFin
        self.notas = notas
    }

    var etapasOrdenadas: [Etapa] {
        etapas.sorted { $0.fechaInicio < $1.fechaInicio }
    }
}
