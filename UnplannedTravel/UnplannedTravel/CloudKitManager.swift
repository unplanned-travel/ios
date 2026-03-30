import CloudKit
import SwiftData

// MARK: - Serialisable snapshot of an Etapa

private struct EtapaSnapshot: Codable {
    var tipoRaw: String
    var fechaInicio: Date
    var fechaFin: Date?
    var nombre: String?
    var notas: String?
    var coste: Coste?
    var origen: Direccion?
    var destino: Direccion?
    var direccion: Direccion?
    var reserva: Reserva?
    var rutaCircular: Bool?

    init(_ etapa: Etapa) {
        tipoRaw = etapa.tipoRaw
        fechaInicio = etapa.fechaInicio
        fechaFin = etapa.fechaFin
        nombre = etapa.nombre
        notas = etapa.notas
        coste = etapa.coste
        origen = etapa.origen
        destino = etapa.destino
        direccion = etapa.direccion
        reserva = etapa.reserva
        rutaCircular = etapa.rutaCircular
    }
}

// MARK: - CloudKit manager

@MainActor
final class CloudKitManager {

    static let shared = CloudKitManager()

    private let containerID = "iCloud.com.jaureguialzo.UnplannedTravel"
    private var ckContainer: CKContainer { CKContainer(identifier: containerID) }
    private var privateDB: CKDatabase { ckContainer.privateCloudDatabase }
    private var sharedDB: CKDatabase { ckContainer.sharedCloudDatabase }

    // MARK: Sharing a plan (owner side)

    /// Creates (or retrieves) the CKRecord + CKShare for `plan` and returns the share.
    /// Called from the UICloudSharingController preparation handler.
    func prepararShare(para plan: Plan) async throws -> (CKRecord, CKShare) {
        let record = try await obtenerOCrearRecord(para: plan)

        // Check if a share already exists for this record.
        if let existingShare = try? await privateDB.record(for: CKRecord.ID(recordName: "\(record.recordID.recordName).share")) as? CKShare {
            return (record, existingShare)
        }

        let share = CKShare(rootRecord: record)
        share[CKShare.SystemFieldKey.title] = (plan.titulo.isEmpty ? "Viaje" : plan.titulo) as CKRecordValue
        share.publicPermission = .none  // Invite-only

        let results = try await privateDB.modifyRecords(saving: [record, share], deleting: [])

        let savedShare = results.saveResults.compactMap { _, result -> CKShare? in
            guard let record = try? result.get() else { return nil }
            return record as? CKShare
        }.first ?? share

        plan.estaCompartido = true
        return (record, savedShare)
    }

    // MARK: Syncing changes (owner pushes updates to CloudKit)

    /// Pushes the current state of `plan` to its CloudKit record so participants see the changes.
    func sincronizarPlan(_ plan: Plan) async throws {
        let record = try await obtenerOCrearRecord(para: plan)
        rellenarRecord(record, desde: plan)
        _ = try await privateDB.save(record)
    }

    // MARK: Accepting an invitation (participant side)

    /// Accepts the incoming share and imports the plan into the local SwiftData context.
    func aceptarYImportar(
        metadata: CKShare.Metadata,
        en context: ModelContext
    ) async throws {
        try await ckContainer.accept(metadata)

        let record = try await sharedDB.record(for: metadata.rootRecordID)
        let plan = planDesdeRecord(record)
        context.insert(plan)

        // Mark as externally shared so the UI can show the shared badge.
        plan.estaCompartido = true
    }

    // MARK: Refreshing a shared plan (participant pulls latest)

    /// Fetches the latest version of the plan from the CloudKit shared database.
    func actualizarPlanCompartido(_ plan: Plan, en context: ModelContext) async throws {
        guard let recordID = plan.cloudKitRecordID else { return }
        let record = try await sharedDB.record(for: CKRecord.ID(recordName: recordID))
        actualizarPlan(plan, desdeRecord: record)
    }

    // MARK: Checking iCloud availability

    func iCloudDisponible() async -> Bool {
        let status = try? await ckContainer.accountStatus()
        return status == .available
    }

    // MARK: - Private helpers

    private func obtenerOCrearRecord(para plan: Plan) async throws -> CKRecord {
        if let name = plan.cloudKitRecordID {
            if let existing = try? await privateDB.record(for: CKRecord.ID(recordName: name)) {
                rellenarRecord(existing, desde: plan)
                return existing
            }
        }
        let record = CKRecord(recordType: "Plan")
        rellenarRecord(record, desde: plan)
        plan.cloudKitRecordID = record.recordID.recordName
        return record
    }

    private func rellenarRecord(_ record: CKRecord, desde plan: Plan) {
        record["titulo"] = (plan.titulo.isEmpty ? "Viaje" : plan.titulo) as CKRecordValue
        record["fechaInicio"] = plan.fechaInicio as CKRecordValue?
        record["fechaFin"] = plan.fechaFin as CKRecordValue?
        record["notas"] = plan.notas as CKRecordValue?
        let snapshots = plan.etapasOrdenadas.map { EtapaSnapshot($0) }
        if let data = try? JSONEncoder().encode(snapshots),
           let json = String(data: data, encoding: .utf8) {
            record["etapasJSON"] = json as CKRecordValue
        }
    }

    private func planDesdeRecord(_ record: CKRecord) -> Plan {
        let plan = Plan(
            titulo: record["titulo"] as? String ?? "",
            fechaInicio: record["fechaInicio"] as? Date,
            fechaFin: record["fechaFin"] as? Date,
            notas: record["notas"] as? String
        )
        plan.cloudKitRecordID = record.recordID.recordName
        actualizarEtapas(plan, desdeRecord: record)
        return plan
    }

    private func actualizarPlan(_ plan: Plan, desdeRecord record: CKRecord) {
        plan.titulo = record["titulo"] as? String ?? plan.titulo
        plan.fechaInicio = record["fechaInicio"] as? Date ?? plan.fechaInicio
        plan.fechaFin = record["fechaFin"] as? Date
        plan.notas = record["notas"] as? String
        // Replace etapas with the latest from CloudKit.
        plan.etapas.forEach { $0.plan = nil }
        plan.etapas.removeAll()
        actualizarEtapas(plan, desdeRecord: record)
    }

    private func actualizarEtapas(_ plan: Plan, desdeRecord record: CKRecord) {
        guard let json = record["etapasJSON"] as? String,
              let data = json.data(using: .utf8),
              let snapshots = try? JSONDecoder().decode([EtapaSnapshot].self, from: data)
        else { return }

        for s in snapshots {
            let etapa = Etapa(
                tipo: TipoEtapa(rawValue: s.tipoRaw) ?? .actividad,
                fechaInicio: s.fechaInicio
            )
            etapa.fechaFin = s.fechaFin
            etapa.nombre = s.nombre
            etapa.notas = s.notas
            etapa.coste = s.coste
            etapa.origen = s.origen
            etapa.destino = s.destino
            etapa.direccion = s.direccion
            etapa.reserva = s.reserva
            etapa.rutaCircular = s.rutaCircular
            etapa.plan = plan
        }
    }
}
