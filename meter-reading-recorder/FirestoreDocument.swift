import Foundation
import CoreData

struct MeterReadingDocument: Codable {
    let id: String
    let userId: String
    let type: String
    let value: String
    let date: Date
    let createdAt: Date
    let updatedAt: Date
    let deletedAt: Date?
    let deviceId: String
    let version: Int64
    let imagePath: String?

    init(id: String, userId: String, type: String, value: String, date: Date,
         createdAt: Date, updatedAt: Date, deletedAt: Date?, deviceId: String,
         version: Int64, imagePath: String?) {
        self.id = id
        self.userId = userId
        self.type = type
        self.value = value
        self.date = date
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.deletedAt = deletedAt
        self.deviceId = deviceId
        self.version = version
        self.imagePath = imagePath
    }

    init(reading: MeterReading) {
        self.id = reading.id?.uuidString ?? UUID().uuidString
        self.userId = reading.userId ?? ""
        self.type = reading.meterType ?? ""
        self.value = reading.value ?? ""
        self.date = reading.date ?? Date()
        self.createdAt = reading.createdAt ?? Date()
        self.updatedAt = reading.modifiedAt ?? Date()
        self.deletedAt = reading.softDeleted ? reading.deletedAt : nil
        self.deviceId = reading.deviceId ?? DeviceIdentifier.current
        self.version = reading.version
        self.imagePath = reading.cloudImagePath
    }

    func apply(to reading: MeterReading, context: NSManagedObjectContext) {
        reading.id = UUID(uuidString: id) ?? reading.id
        reading.userId = userId
        reading.meterType = type
        reading.value = value
        reading.date = date
        reading.createdAt = createdAt
        reading.modifiedAt = updatedAt
        reading.deviceId = deviceId
        reading.version = version
        reading.cloudImagePath = imagePath

        if let deletedAt = deletedAt {
            reading.softDeleted = true
            reading.deletedAt = deletedAt
        } else {
            reading.softDeleted = false
            reading.deletedAt = nil
        }

        reading.syncStatusEnum = .synced
    }

    var firestoreData: [String: Any] {
        var data: [String: Any] = [
            "id": id,
            "userId": userId,
            "type": type,
            "value": value,
            "date": date,
            "createdAt": createdAt,
            "updatedAt": updatedAt,
            "deviceId": deviceId,
            "version": version
        ]
        if let deletedAt = deletedAt {
            data["deletedAt"] = deletedAt
        }
        if let imagePath = imagePath {
            data["imagePath"] = imagePath
        }
        return data
    }

    static func from(firestoreData data: [String: Any]) -> MeterReadingDocument? {
        guard let id = data["id"] as? String,
              let userId = data["userId"] as? String,
              let type = data["type"] as? String,
              let value = data["value"] as? String,
              let deviceId = data["deviceId"] as? String,
              let version = data["version"] as? Int64 else {
            return nil
        }

        let date = (data["date"] as? Date) ?? Date()
        let createdAt = (data["createdAt"] as? Date) ?? Date()
        let updatedAt = (data["updatedAt"] as? Date) ?? Date()
        let deletedAt = data["deletedAt"] as? Date
        let imagePath = data["imagePath"] as? String

        return MeterReadingDocument(
            id: id,
            userId: userId,
            type: type,
            value: value,
            date: date,
            createdAt: createdAt,
            updatedAt: updatedAt,
            deletedAt: deletedAt,
            deviceId: deviceId,
            version: version,
            imagePath: imagePath
        )
    }
}
