import Foundation
import CoreData
import FirebaseFirestore
import Combine
import os

enum SyncState: Equatable {
    case idle
    case syncing
    case error(String)
    case offline
}

@MainActor
final class SyncService: ObservableObject {
    static let shared = SyncService()

    @Published private(set) var syncState: SyncState = .idle
    @Published private(set) var pendingCount: Int = 0

    private var userId: String?
    private var listener: ListenerRegistration?
    private var saveObserver: NSObjectProtocol?
    private var networkCancellable: AnyCancellable?
    private let db = Firestore.firestore()
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "meter-reading-recorder", category: "Sync")

    private var isSyncing = false

    private init() {}

    func startSync(for userId: String) {
        guard self.userId != userId else { return }
        stopSync()
        self.userId = userId
        logger.info("🔄 Starting sync for user: \(userId, privacy: .private)")

        migrateExistingRecords()
        startListeningToRemoteChanges()
        observeLocalChanges()
        observeNetwork()
        pushPendingChanges()
    }

    func stopSync() {
        listener?.remove()
        listener = nil

        if let observer = saveObserver {
            NotificationCenter.default.removeObserver(observer)
            saveObserver = nil
        }

        networkCancellable?.cancel()
        networkCancellable = nil

        userId = nil
        syncState = .idle
        pendingCount = 0
        logger.info("Sync stopped")
    }

    // MARK: - Migration for existing records

    private func migrateExistingRecords() {
        let context = PersistenceController.shared.container.newBackgroundContext()
        context.perform {
            let request = MeterReading.fetchRequest()
            request.predicate = NSPredicate(format: "version == 0")

            do {
                let results = try context.fetch(request)
                guard !results.isEmpty else {
                    self.logger.info("Migration: no records to migrate")
                    return
                }
                self.logger.info("Migration: migrating \(results.count) records")
                for reading in results {
                    reading.syncStatus = SyncStatus.pending.rawValue
                    reading.version = 1
                    reading.deviceId = DeviceIdentifier.current
                    self.logger.debug("Migration: queued reading \(reading.id?.uuidString ?? "nil", privacy: .private) (type=\(reading.meterType ?? "nil"), userId=\(reading.userId ?? "nil", privacy: .private))")
                }
                try context.save()
                self.logger.info("Migration: saved successfully")
            } catch {
                self.logger.error("Migration: fetch/save failed — \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Remote Listener

    private func startListeningToRemoteChanges() {
        guard let userId = userId else { return }

        let collectionRef = db.collection("users").document(userId).collection("readings")
        logger.info("Listener: subscribing to users/\(userId, privacy: .private)/readings")

        listener = collectionRef.addSnapshotListener { [weak self] snapshot, error in
            guard let self = self else { return }

            if let error = error as? NSError {
                Task { @MainActor in
                    self.logger.error("Listener: ❌ error — domain=\(error.domain), code=\(error.code), description=\(error.localizedDescription)")
                    self.syncState = .error(error.localizedDescription)
                }
                return
            }

            guard let snapshot = snapshot else {
                Task { @MainActor in
                    self.logger.warning("Listener: received nil snapshot")
                }
                return
            }

            Task { @MainActor in
                self.logger.info("Listener: snapshot with \(snapshot.documentChanges.count) change(s), \(snapshot.documents.count) total doc(s), fromCache=\(snapshot.metadata.isFromCache)")
                await self.processRemoteChanges(snapshot.documentChanges)
            }
        }
    }

    private func processRemoteChanges(_ changes: [DocumentChange]) async {
        logger.info("Remote: processing \(changes.count) change(s)")
        let context = PersistenceController.shared.container.newBackgroundContext()

        await context.perform {
            for change in changes {
                let data = change.document.data()
                let docId = change.document.documentID

                guard let doc = self.parseFirestoreDocument(data) else {
                    self.logger.warning("Remote: failed to parse document \(docId) — keys: \(Array(data.keys))")
                    continue
                }
                guard let readingId = UUID(uuidString: doc.id) else {
                    self.logger.warning("Remote: invalid UUID in document \(docId): '\(doc.id)'")
                    continue
                }

                let changeType: String
                switch change.type {
                case .added: changeType = "added"
                case .modified: changeType = "modified"
                case .removed: changeType = "removed"
                }
                self.logger.info("Remote: \(changeType) \(docId) (value=\(doc.value), version=\(doc.version))")

                let request = MeterReading.fetchRequest()
                request.predicate = NSPredicate(format: "id == %@", readingId as CVarArg)
                let existing = try? context.fetch(request).first

                switch change.type {
                case .added, .modified:
                    if let existing = existing {
                        self.logger.debug("Remote: local record exists (syncStatus=\(existing.syncStatus), version=\(existing.version))")
                        self.resolveConflict(local: existing, remote: doc, context: context)
                    } else {
                        self.logger.info("Remote: creating new local record for \(docId)")
                        let newReading = MeterReading(context: context)
                        doc.apply(to: newReading, context: context)
                    }
                case .removed:
                    if let existing = existing {
                        self.logger.info("Remote: deleting local record \(docId)")
                        context.delete(existing)
                    }
                }
            }

            do {
                try context.save()
            } catch {
                self.logger.error("Remote: failed to save context — \(error.localizedDescription)")
            }
        }

        updatePendingCount()
    }

    // MARK: - Conflict Resolution

    private func resolveConflict(local: MeterReading, remote: MeterReadingDocument, context: NSManagedObjectContext) {
        let readingId = local.id?.uuidString ?? "nil"

        // If local is already synced or stuck in error, accept the remote data
        if local.syncStatusEnum == .synced || local.syncStatusEnum == .error {
            logger.debug("Conflict: \(readingId) — local is \(local.syncStatusEnum == .synced ? "synced" : "error"), applying remote (version \(remote.version))")
            remote.apply(to: local, context: context)
            return
        }

        // If local has pending changes, apply conflict resolution strategy
        let localDeviceId = local.deviceId ?? ""
        let remoteDeviceId = remote.deviceId
        let localUpdatedAt = local.modifiedAt ?? Date.distantPast
        let remoteUpdatedAt = remote.updatedAt
        let timeGap = abs(localUpdatedAt.timeIntervalSince(remoteUpdatedAt))

        logger.info("Conflict: \(readingId) — localStatus=\(local.syncStatus), localVersion=\(local.version), remoteVersion=\(remote.version), localDevice=\(localDeviceId), remoteDevice=\(remoteDeviceId), timeGap=\(String(format: "%.1f", timeGap))s")

        if localDeviceId == remoteDeviceId {
            if remoteUpdatedAt > localUpdatedAt {
                logger.info("Conflict: \(readingId) — same device, remote newer → applying remote")
                remote.apply(to: local, context: context)
            } else {
                logger.info("Conflict: \(readingId) — same device, local newer → keeping local")
            }
        } else if timeGap > 60 {
            if remoteUpdatedAt > localUpdatedAt {
                logger.info("Conflict: \(readingId) — large time gap, remote newer → applying remote")
                remote.apply(to: local, context: context)
            } else {
                logger.info("Conflict: \(readingId) — large time gap, local newer → keeping local")
            }
        } else if local.value == remote.value {
            if remoteUpdatedAt > localUpdatedAt {
                logger.info("Conflict: \(readingId) — same value, remote newer → applying remote")
                remote.apply(to: local, context: context)
            } else {
                logger.info("Conflict: \(readingId) — same value, local newer → keeping local")
            }
        } else {
            logger.warning("Conflict: \(readingId) — TRUE CONFLICT flagged for user resolution (localValue=\(local.value ?? "nil"), remoteValue=\(remote.value))")
            let conflictInfo = ConflictData(
                value: remote.value,
                date: remote.date,
                updatedAt: remote.updatedAt,
                deviceId: remote.deviceId,
                version: remote.version,
                imagePath: remote.imagePath
            )
            local.conflictData = try? JSONEncoder().encode(conflictInfo)
            local.syncStatusEnum = .conflict
        }
    }

    // MARK: - Push Local Changes

    func pushPendingChanges() {
        guard let userId = userId else {
            logger.warning("Push: skipped — no userId set")
            return
        }
        guard !isSyncing else {
            logger.debug("Push: skipped — already syncing")
            return
        }
        guard NetworkMonitor.shared.isConnected else {
            logger.info("Push: skipped — offline")
            syncState = .offline
            return
        }

        isSyncing = true
        syncState = .syncing
        logger.info("Push: starting push cycle for user \(userId, privacy: .private)")

        let context = PersistenceController.shared.container.newBackgroundContext()

        Task {
            await context.perform {
                let request = MeterReading.fetchRequest()
                request.predicate = NSPredicate(format: "(syncStatus == %d OR syncStatus == %d) AND userId == %@",
                                                SyncStatus.pending.rawValue, SyncStatus.error.rawValue, userId)

                do {
                    let pushableReadings = try context.fetch(request)
                    guard !pushableReadings.isEmpty else {
                        self.logger.info("Push: no pending/error readings found")
                        return
                    }
                    self.logger.info("Push: found \(pushableReadings.count) reading(s) to push")

                    for reading in pushableReadings {
                        // Fix missing deviceId from pre-sync records
                        if reading.deviceId == nil || reading.deviceId?.isEmpty == true {
                            reading.deviceId = DeviceIdentifier.current
                        }
                        self.logger.debug("Push: queuing \(reading.id?.uuidString ?? "nil") (type=\(reading.meterType ?? "nil"), value=\(reading.value ?? "nil"), version=\(reading.version), syncStatus=\(reading.syncStatus), userId=\(reading.userId ?? "nil", privacy: .private))")
                        Task { [weak self] in
                            await self?.pushSingleReading(reading, userId: userId, context: context)
                        }
                    }
                } catch {
                    self.logger.error("Push: fetch failed — \(error.localizedDescription)")
                }
            }

            await MainActor.run {
                self.isSyncing = false
                self.syncState = .idle
                self.updatePendingCount()
            }
        }
    }

    private func pushSingleReading(_ reading: MeterReading, userId: String, context: NSManagedObjectContext) async {
        guard let readingId = reading.id else {
            logger.warning("Push: skipping reading with nil id")
            return
        }

        let doc = await context.perform { MeterReadingDocument(reading: reading) }
        let path = "users/\(userId)/readings/\(readingId.uuidString)"
        let docRef = db.collection("users").document(userId).collection("readings").document(readingId.uuidString)

        logger.info("Push: writing \(path) — value=\(doc.value), version=\(doc.version), deviceId=\(doc.deviceId), type=\(doc.type)")
        logger.debug("Push: firestoreData keys=\(Array(doc.firestoreData.keys))")

        do {
            try await docRef.setData(doc.firestoreData, merge: true)
            await context.perform {
                reading.syncStatusEnum = .synced
                try? context.save()
            }
            logger.info("Push: ✅ success \(readingId)")
        } catch let error as NSError {
            logger.error("Push: ❌ FAILED \(readingId) — domain=\(error.domain), code=\(error.code), description=\(error.localizedDescription)")
            if let underlying = error.userInfo[NSUnderlyingErrorKey] as? NSError {
                logger.error("Push: ❌ underlying — domain=\(underlying.domain), code=\(underlying.code), description=\(underlying.localizedDescription)")
            }
            logger.error("Push: ❌ userInfo=\(error.userInfo.keys.map { String(describing: $0) })")
            await context.perform {
                reading.syncStatusEnum = .error
                try? context.save()
            }
        }
    }

    // MARK: - Observe Local Changes

    private func observeLocalChanges() {
        saveObserver = NotificationCenter.default.addObserver(
            forName: .NSManagedObjectContextDidSave,
            object: PersistenceController.shared.container.viewContext,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.updatePendingCount()
                self?.pushPendingChanges()
            }
        }
    }

    // MARK: - Network Observation

    private func observeNetwork() {
        networkCancellable = NetworkMonitor.shared.$isConnected
            .removeDuplicates()
            .sink { [weak self] connected in
                Task { @MainActor in
                    guard let self = self else { return }
                    self.logger.info("Network: connectivity changed → \(connected ? "online" : "offline")")
                    if connected {
                        self.syncState = .idle
                        self.pushPendingChanges()
                    } else {
                        self.syncState = .offline
                    }
                }
            }
    }

    // MARK: - User Conflict Resolution

    func resolveConflictKeepLocal(_ reading: MeterReading) {
        reading.conflictData = nil
        reading.syncStatusEnum = .pending
        reading.version += 1
        reading.modifiedAt = Date()
        reading.deviceId = DeviceIdentifier.current
        try? reading.managedObjectContext?.save()
    }

    func resolveConflictAcceptRemote(_ reading: MeterReading) {
        guard let conflict = reading.decodedConflictData else { return }
        reading.value = conflict.value
        reading.date = conflict.date
        reading.modifiedAt = conflict.updatedAt
        reading.deviceId = conflict.deviceId
        reading.version = conflict.version
        reading.conflictData = nil
        reading.syncStatusEnum = .synced
        try? reading.managedObjectContext?.save()
    }

    // MARK: - Helpers

    private func updatePendingCount() {
        let context = PersistenceController.shared.container.viewContext
        let request = MeterReading.fetchRequest()
        request.predicate = NSPredicate(format: "syncStatus == %d", SyncStatus.pending.rawValue)
        pendingCount = (try? context.count(for: request)) ?? 0
    }

    private func parseFirestoreDocument(_ data: [String: Any]) -> MeterReadingDocument? {
        var parsed = data
        // Convert Firestore Timestamps to Dates
        for key in ["date", "createdAt", "updatedAt", "deletedAt"] {
            if let timestamp = parsed[key] as? Timestamp {
                parsed[key] = timestamp.dateValue()
            }
        }
        return MeterReadingDocument.from(firestoreData: parsed)
    }
}
