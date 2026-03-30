import CloudKit
import Observation

@Observable
@MainActor
final class CloudKitStore {

    // MARK: - Singleton (for AppDelegate access)

    static var shared: CloudKitStore?

    // MARK: - Constants

    static let containerID = "iCloud.com.jaureguialzo.UnplannedTravel"
    static let zoneName = "UnplannedZone"
    private static var zona: CKRecordZone { CKRecordZone(zoneName: zoneName) }

    // MARK: - Published state

    var planes: [Plan] = []
    var etapasPorPlan: [CKRecord.ID: [Etapa]] = [:]
    var cargando = false
    var errorMensaje: String?
    var cuentaDisponible = false

    // MARK: - CloudKit

    let ckContainer = CKContainer(identifier: CloudKitStore.containerID)
    private var privateDB: CKDatabase { ckContainer.privateCloudDatabase }
    private var sharedDB: CKDatabase { ckContainer.sharedCloudDatabase }

    // Stored CKRecords needed to supply system fields (recordChangeTag) on updates.
    private var planRecords: [CKRecord.ID: CKRecord] = [:]
    private var etapaRecords: [CKRecord.ID: CKRecord] = [:]

    // MARK: - Server change tokens

    private let defaults = UserDefaults.standard

    private var privateDBToken: CKServerChangeToken? {
        get { token(key: "ck.db.private") }
        set { setToken(newValue, key: "ck.db.private") }
    }

    private var sharedDBToken: CKServerChangeToken? {
        get { token(key: "ck.db.shared") }
        set { setToken(newValue, key: "ck.db.shared") }
    }

    private func token(key: String) -> CKServerChangeToken? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? NSKeyedUnarchiver.unarchivedObject(ofClass: CKServerChangeToken.self, from: data)
    }

    private func setToken(_ token: CKServerChangeToken?, key: String) {
        if let token, let data = try? NSKeyedArchiver.archivedData(withRootObject: token, requiringSecureCoding: true) {
            defaults.set(data, forKey: key)
        } else {
            defaults.removeObject(forKey: key)
        }
    }

    private func zoneToken(_ zoneID: CKRecordZone.ID) -> CKServerChangeToken? {
        token(key: "ck.zone.\(zoneID.zoneName).\(zoneID.ownerName)")
    }

    private func setZoneToken(_ token: CKServerChangeToken?, _ zoneID: CKRecordZone.ID) {
        setToken(token, key: "ck.zone.\(zoneID.zoneName).\(zoneID.ownerName)")
    }

    // MARK: - Lifecycle

    init() {
        CloudKitStore.shared = self
        Task { await setup() }
    }

    func setup() async {
        do {
            let status = try await ckContainer.accountStatus()
            guard status == .available else {
                errorMensaje = accountStatusMessage(status)
                return
            }
            cuentaDisponible = true
            try await crearZona()
            try await registrarSuscripciones()
            await cargarDatos()
        } catch {
            errorMensaje = error.localizedDescription
        }
    }

    private func accountStatusMessage(_ status: CKAccountStatus) -> String {
        switch status {
        case .noAccount:
            return "Sign in to iCloud in Settings to use Unplanned."
        case .restricted:
            return "iCloud access is restricted on this device."
        case .couldNotDetermine:
            return "Could not determine iCloud account status. Check your connection."
        case .temporarilyUnavailable:
            return "iCloud is temporarily unavailable. Try again later."
        default:
            return "iCloud account is not available."
        }
    }

    // MARK: - Zone

    private func crearZona() async throws {
        let key = "ck.zona.creada"
        guard !defaults.bool(forKey: key) else { return }
        _ = try await privateDB.save(Self.zona)
        defaults.set(true, forKey: key)
    }

    // MARK: - Subscriptions

    private func registrarSuscripciones() async throws {
        let info = CKSubscription.NotificationInfo()
        info.shouldSendContentAvailable = true  // silent push

        let subPrivate = CKDatabaseSubscription(subscriptionID: "unplanned-private-changes")
        subPrivate.notificationInfo = info

        let subShared = CKDatabaseSubscription(subscriptionID: "unplanned-shared-changes")
        subShared.notificationInfo = info

        _ = try? await privateDB.save(subPrivate)
        _ = try? await sharedDB.save(subShared)
    }

    // MARK: - Load all data

    func cargarDatos() async {
        cargando = true
        defer { cargando = false }

        // Clear state for a full reload
        planRecords.removeAll()
        etapaRecords.removeAll()
        planes.removeAll()
        etapasPorPlan.removeAll()

        // Private database: full zone fetch with nil token (no CKQuery needed)
        await fetchTodosRegistros(zoneID: Self.zona.zoneID, db: privateDB, esPropio: true)

        // Shared database: discover zones, then full fetch each
        do {
            let sharedZoneIDs = try await fetchSharedZoneIDs()
            for zoneID in sharedZoneIDs {
                await fetchTodosRegistros(zoneID: zoneID, db: sharedDB, esPropio: false)
            }
        } catch {
            print("[CloudKit] Error fetching shared zones: \(error)")
        }
    }

    /// Full fetch of all records in a zone using CKFetchRecordZoneChangesOperation
    /// with nil token — works without any Queryable schema configuration.
    private func fetchTodosRegistros(zoneID: CKRecordZone.ID, db: CKDatabase, esPropio: Bool) async {
        do {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                var changed: [CKRecord] = []
                let config = CKFetchRecordZoneChangesOperation.ZoneConfiguration(
                    previousServerChangeToken: nil
                )
                let op = CKFetchRecordZoneChangesOperation(
                    recordZoneIDs: [zoneID],
                    configurationsByRecordZoneID: [zoneID: config]
                )
                op.recordWasChangedBlock = { _, result in
                    if let record = try? result.get() { changed.append(record) }
                }
                op.fetchRecordZoneChangesResultBlock = { result in
                    switch result {
                    case .success:
                        Task { @MainActor in self.aplicarCambios(changed, deleted: [], esPropio: esPropio) }
                        continuation.resume()
                    case .failure(let error):
                        continuation.resume(throwing: error)
                    }
                }
                db.add(op)
            }
        } catch {
            print("[CloudKit] fetchTodosRegistros error: \(error)")
        }
    }

    // MARK: - Helpers: etapas

    func etapasOrdenadas(para planID: CKRecord.ID) -> [Etapa] {
        (etapasPorPlan[planID] ?? []).sorted { $0.fechaInicio < $1.fechaInicio }
    }

    // MARK: - CRUD Plans

    func crearPlan(_ borrador: Plan) async throws -> Plan {
        let record = CKRecord(recordType: "Plan", recordID: CKRecord.ID(zoneID: Self.zona.zoneID))
        aplicar(borrador, a: record)
        let saved = try await privateDB.save(record)
        planRecords[saved.recordID] = saved
        let plan = Plan(from: saved, esPropio: true)
        planes.append(plan)
        planes.sort { ($0.fechaInicio ?? .distantFuture) < ($1.fechaInicio ?? .distantFuture) }
        return plan
    }

    func actualizarPlan(_ plan: Plan) async throws {
        guard let record = planRecords[plan.id] else { return }
        aplicar(plan, a: record)
        let saved = try await db(plan).save(record)
        planRecords[saved.recordID] = saved
        if let idx = planes.firstIndex(where: { $0.id == plan.id }) {
            planes[idx] = Plan(from: saved, esPropio: plan.esPropio)
        }
        planes.sort { ($0.fechaInicio ?? .distantFuture) < ($1.fechaInicio ?? .distantFuture) }
    }

    func eliminarPlan(_ plan: Plan) async throws {
        try await db(plan).deleteRecord(withID: plan.id)
        planRecords.removeValue(forKey: plan.id)
        planes.removeAll { $0.id == plan.id }
        etapasPorPlan.removeValue(forKey: plan.id)
    }

    // MARK: - CRUD Etapas

    func crearEtapa(_ borrador: Etapa) async throws -> Etapa {
        guard let planRecord = planRecords[borrador.planID] else { return borrador }
        let record = CKRecord(recordType: "Etapa", recordID: CKRecord.ID(zoneID: planRecord.recordID.zoneID))
        aplicar(borrador, a: record)
        let saved = try await db(planID: borrador.planID).save(record)
        etapaRecords[saved.recordID] = saved
        let etapa = Etapa(from: saved)
        etapasPorPlan[etapa.planID, default: []].append(etapa)
        return etapa
    }

    func actualizarEtapa(_ etapa: Etapa) async throws {
        guard let record = etapaRecords[etapa.id] else { return }
        aplicar(etapa, a: record)
        let saved = try await db(planID: etapa.planID).save(record)
        etapaRecords[saved.recordID] = saved
        if var lista = etapasPorPlan[etapa.planID],
           let idx = lista.firstIndex(where: { $0.id == etapa.id }) {
            lista[idx] = Etapa(from: saved)
            etapasPorPlan[etapa.planID] = lista
        }
    }

    func eliminarEtapa(_ etapa: Etapa) async throws {
        try await db(planID: etapa.planID).deleteRecord(withID: etapa.id)
        etapaRecords.removeValue(forKey: etapa.id)
        etapasPorPlan[etapa.planID]?.removeAll { $0.id == etapa.id }
    }

    // MARK: - Database selector

    private func db(_ plan: Plan) -> CKDatabase {
        plan.esPropio ? privateDB : sharedDB
    }

    private func db(planID: CKRecord.ID) -> CKDatabase {
        let plan = planes.first { $0.id == planID }
        return (plan?.esPropio ?? true) ? privateDB : sharedDB
    }

    // MARK: - Record fill helpers

    private func aplicar(_ plan: Plan, a record: CKRecord) {
        record["titulo"] = plan.titulo as CKRecordValue
        record["fechaInicio"] = plan.fechaInicio as CKRecordValue?
        record["fechaFin"] = plan.fechaFin as CKRecordValue?
        record["notas"] = plan.notas as CKRecordValue?
    }

    private func aplicar(_ etapa: Etapa, a record: CKRecord) {
        record["planRef"] = CKRecord.Reference(recordID: etapa.planID, action: .deleteSelf) as CKRecordValue
        record["tipoRaw"] = etapa.tipoRaw as CKRecordValue
        record["fechaInicio"] = etapa.fechaInicio as CKRecordValue
        record["fechaFin"] = etapa.fechaFin as CKRecordValue?
        record["nombre"] = etapa.nombre as CKRecordValue?
        record["notas"] = etapa.notas as CKRecordValue?
        record["orden"] = etapa.orden as CKRecordValue
        record["rutaCircular"] = etapa.rutaCircular.map { $0 ? 1 : 0 } as CKRecordValue?
        record["costeJSON"] = Etapa.codificar(etapa.coste) as CKRecordValue?
        record["origenJSON"] = Etapa.codificar(etapa.origen) as CKRecordValue?
        record["destinoJSON"] = Etapa.codificar(etapa.destino) as CKRecordValue?
        record["direccionJSON"] = Etapa.codificar(etapa.direccion) as CKRecordValue?
        record["reservaJSON"] = Etapa.codificar(etapa.reserva) as CKRecordValue?
    }

    // MARK: - Sharing

    func prepararShare(para plan: Plan) async throws -> (CKRecord, CKShare) {
        guard let record = planRecords[plan.id] else {
            throw NSError(domain: "CloudKitStore", code: 1,
                         userInfo: [NSLocalizedDescriptionKey: "Record not found in local cache"])
        }

        // Reuse existing share if the record is already shared.
        if let shareRef = record.share,
           let existingShare = try? await privateDB.record(for: shareRef.recordID) as? CKShare {
            return (record, existingShare)
        }

        let share = CKShare(rootRecord: record)
        share[CKShare.SystemFieldKey.title] = (plan.titulo.isEmpty ? "Trip" : plan.titulo) as CKRecordValue
        share.publicPermission = .none

        let results = try await privateDB.modifyRecords(saving: [record, share], deleting: [])
        let savedShare = results.saveResults.values.compactMap { try? $0.get() as? CKShare }.first ?? share
        planRecords[plan.id] = record

        if let idx = planes.firstIndex(where: { $0.id == plan.id }) {
            planes[idx].estaCompartido = true
        }

        return (record, savedShare)
    }

    func aceptarShare(metadata: CKShare.Metadata) async throws {
        try await ckContainer.accept(metadata)
        await cargarDatos()
    }

    // MARK: - Real-time sync (called from AppDelegate on silent push)

    func procesarNotificacionRemota(_ userInfo: [AnyHashable: Any]) async {
        guard let notification = CKNotification(fromRemoteNotificationDictionary: userInfo) else { return }
        switch notification.subscriptionID {
        case "unplanned-private-changes":
            await fetchCambiosPrivate()
        case "unplanned-shared-changes":
            await fetchCambiosShared()
        default:
            await cargarDatos()
        }
    }

    func fetchCambios() async {
        await fetchCambiosPrivate()
        await fetchCambiosShared()
    }

    private func fetchCambiosPrivate() async {
        do {
            let changedZoneIDs = try await fetchChangedZoneIDs(db: privateDB, token: privateDBToken) { [weak self] newToken in
                self?.privateDBToken = newToken
            }
            for zoneID in changedZoneIDs {
                await fetchCambiosZona(zoneID, db: privateDB, esPropio: true)
            }
        } catch {
            print("[CloudKit] fetchCambiosPrivate error: \(error)")
        }
    }

    private func fetchCambiosShared() async {
        do {
            let changedZoneIDs = try await fetchChangedZoneIDs(db: sharedDB, token: sharedDBToken) { [weak self] newToken in
                self?.sharedDBToken = newToken
            }
            for zoneID in changedZoneIDs {
                await fetchCambiosZona(zoneID, db: sharedDB, esPropio: false)
            }
        } catch {
            print("[CloudKit] fetchCambiosShared error: \(error)")
        }
    }

    // MARK: - Delta fetch

    private func fetchChangedZoneIDs(
        db: CKDatabase,
        token: CKServerChangeToken?,
        updateToken: @escaping @MainActor (CKServerChangeToken?) -> Void
    ) async throws -> [CKRecordZone.ID] {
        try await withCheckedThrowingContinuation { continuation in
            var changed: [CKRecordZone.ID] = []
            let op = CKFetchDatabaseChangesOperation(previousServerChangeToken: token)
            op.recordZoneWithIDChangedBlock = { changed.append($0) }
            op.fetchDatabaseChangesResultBlock = { result in
                switch result {
                case .success(let (newToken, _)):
                    Task { @MainActor in updateToken(newToken) }
                    continuation.resume(returning: changed)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
            db.add(op)
        }
    }

    private func fetchCambiosZona(_ zoneID: CKRecordZone.ID, db: CKDatabase, esPropio: Bool) async {
        do {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                var changed: [CKRecord] = []
                var deleted: [(CKRecord.ID, CKRecord.RecordType)] = []

                let config = CKFetchRecordZoneChangesOperation.ZoneConfiguration(
                    previousServerChangeToken: zoneToken(zoneID)
                )
                let op = CKFetchRecordZoneChangesOperation(
                    recordZoneIDs: [zoneID],
                    configurationsByRecordZoneID: [zoneID: config]
                )
                op.recordWasChangedBlock = { _, result in
                    if let record = try? result.get() { changed.append(record) }
                }
                op.recordWithIDWasDeletedBlock = { id, type in deleted.append((id, type)) }
                op.recordZoneFetchResultBlock = { zoneID, result in
                    if case .success(let (newToken, _, _)) = result {
                        Task { @MainActor in self.setZoneToken(newToken, zoneID) }
                    }
                }
                op.fetchRecordZoneChangesResultBlock = { result in
                    switch result {
                    case .success:
                        Task { @MainActor in self.aplicarCambios(changed, deleted: deleted, esPropio: esPropio) }
                        continuation.resume()
                    case .failure(let error):
                        continuation.resume(throwing: error)
                    }
                }
                db.add(op)
            }
        } catch {
            print("[CloudKit] fetchCambiosZona error: \(error)")
        }
    }

    private func aplicarCambios(_ changed: [CKRecord], deleted: [(CKRecord.ID, CKRecord.RecordType)], esPropio: Bool) {
        for record in changed {
            switch record.recordType {
            case "Plan":
                planRecords[record.recordID] = record
                let plan = Plan(from: record, esPropio: esPropio)
                if let idx = planes.firstIndex(where: { $0.id == record.recordID }) {
                    planes[idx] = plan
                } else {
                    planes.append(plan)
                }
            case "Etapa":
                etapaRecords[record.recordID] = record
                let etapa = Etapa(from: record)
                if var lista = etapasPorPlan[etapa.planID],
                   let idx = lista.firstIndex(where: { $0.id == record.recordID }) {
                    lista[idx] = etapa
                    etapasPorPlan[etapa.planID] = lista
                } else {
                    etapasPorPlan[etapa.planID, default: []].append(etapa)
                }
            default: break
            }
        }

        for (id, _) in deleted {
            planRecords.removeValue(forKey: id)
            etapaRecords.removeValue(forKey: id)
            if planes.contains(where: { $0.id == id }) {
                planes.removeAll { $0.id == id }
                etapasPorPlan.removeValue(forKey: id)
            } else {
                for key in etapasPorPlan.keys {
                    etapasPorPlan[key]?.removeAll { $0.id == id }
                }
            }
        }

        planes.sort { ($0.fechaInicio ?? .distantFuture) < ($1.fechaInicio ?? .distantFuture) }
    }

    // MARK: - Fetch helpers

    private func fetchSharedZoneIDs() async throws -> [CKRecordZone.ID] {
        try await withCheckedThrowingContinuation { continuation in
            var ids: [CKRecordZone.ID] = []
            // nil token = fetch ALL zones (initial load)
            let op = CKFetchDatabaseChangesOperation(previousServerChangeToken: nil)
            op.recordZoneWithIDChangedBlock = { ids.append($0) }
            op.fetchDatabaseChangesResultBlock = { result in
                switch result {
                case .success: continuation.resume(returning: ids)
                case .failure(let error): continuation.resume(throwing: error)
                }
            }
            sharedDB.add(op)
        }
    }
}
