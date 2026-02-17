import CoreData

struct PersistenceController {
    static let shared = PersistenceController()

    @MainActor
    static let preview: PersistenceController = {
        let result = PersistenceController(inMemory: true)
        let viewContext = result.container.viewContext
        for i in 0..<3 {
            let reading = MeterReading(context: viewContext)
            reading.id = UUID()
            reading.value = "\(1000 + i * 100)"
            reading.meterType = MeterType.allCases[i % MeterType.allCases.count].rawValue
            reading.date = Date()
            reading.createdAt = Date()
            reading.modifiedAt = Date()
            reading.softDeleted = false
        }
        try? viewContext.save()
        return result
    }()

    let container: NSPersistentContainer

    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "meter_reading_recorder")

        if inMemory {
            container.persistentStoreDescriptions.first!.url = URL(fileURLWithPath: "/dev/null")
        }

        let description = container.persistentStoreDescriptions.first
        description?.setOption(true as NSNumber, forKey: NSMigratePersistentStoresAutomaticallyOption)
        description?.setOption(true as NSNumber, forKey: NSInferMappingModelAutomaticallyOption)

        container.loadPersistentStores { (storeDescription, error) in
            if let error = error as NSError? {
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        }
        container.viewContext.automaticallyMergesChangesFromParent = true

        if !inMemory {
            migrateV1Data()
            cleanupTombstones()
        }
    }

    /// Backfills timestamps and migrates image BLOBs to filesystem for records from v1.
    private func migrateV1Data() {
        let context = container.newBackgroundContext()
        context.perform {
            let request = MeterReading.fetchRequest()
            request.predicate = NSPredicate(format: "createdAt == nil")

            guard let results = try? context.fetch(request), !results.isEmpty else { return }

            for reading in results {
                let date = reading.date ?? Date()
                reading.createdAt = date
                reading.modifiedAt = Date()
                reading.softDeleted = false

                // Migrate image blob to filesystem
                if let data = reading.imageData, data.count > 0,
                   let readingId = reading.id {
                    if let fileName = ImageStorageService.shared.migrateFromData(data, id: readingId) {
                        reading.imageFileName = fileName
                    }
                    reading.imageData = nil
                }
            }

            try? context.save()
        }
    }

    /// Adopts all local readings (userId == nil) by assigning the given userId and marking for sync.
    func adoptLocalData(for userId: String) {
        let context = container.newBackgroundContext()
        context.perform {
            let request = MeterReading.fetchRequest()
            request.predicate = NSPredicate(format: "userId == nil")

            guard let results = try? context.fetch(request), !results.isEmpty else { return }

            for reading in results {
                reading.userId = userId
                reading.syncStatus = SyncStatus.pending.rawValue
                if reading.version == 0 {
                    reading.version = 1
                }
                if reading.deviceId == nil {
                    reading.deviceId = DeviceIdentifier.current
                }
            }

            try? context.save()

            let objectIDs = results.map { $0.objectID }
            let changes = [NSUpdatedObjectsKey: objectIDs]
            NSManagedObjectContext.mergeChanges(fromRemoteContextSave: changes, into: [self.container.viewContext])
        }
    }

    /// Permanently deletes soft-deleted records older than 30 days that have been synced, and their image files.
    private func cleanupTombstones() {
        let context = container.newBackgroundContext()
        context.perform {
            let request = MeterReading.fetchRequest()
            guard let cutoff = Calendar.current.date(byAdding: .day, value: -30, to: Date()) else { return }
            request.predicate = NSPredicate(
                format: "softDeleted == YES AND deletedAt < %@ AND syncStatus == %d",
                cutoff as NSDate, SyncStatus.synced.rawValue
            )

            guard let tombstones = try? context.fetch(request), !tombstones.isEmpty else { return }

            for reading in tombstones {
                if let fileName = reading.imageFileName {
                    ImageStorageService.shared.deleteImage(fileName: fileName)
                }
                context.delete(reading)
            }

            try? context.save()
        }
    }
}
