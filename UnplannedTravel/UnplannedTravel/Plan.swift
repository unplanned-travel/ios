import Foundation
import SwiftData

@Model final class Plan {
    var titulo: String
    var fechaInicio: Date?
    var fechaFin: Date?
    var notas: String?

    @Relationship(deleteRule: .cascade, inverse: \Etapa.plan)
    var etapas: [Etapa] = []

    /// CloudKit record identifier used to sync this plan to the shared database.
    var cloudKitRecordID: String?
    /// True once a CKShare has been created for this plan.
    var estaCompartido: Bool = false

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
