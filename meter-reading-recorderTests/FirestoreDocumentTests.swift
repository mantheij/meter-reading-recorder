import Testing
import Foundation
import CoreData
@testable import meter_reading_recorder

struct FirestoreDocumentTests {

    @Test func firestoreDataContainsAllRequiredFields() {
        let doc = MeterReadingDocument(
            id: "test-id",
            userId: "user-123",
            type: "water",
            value: "12345",
            date: Date(),
            createdAt: Date(),
            updatedAt: Date(),
            deletedAt: nil,
            deviceId: "device-abc",
            version: 1,
            imagePath: nil
        )

        let data = doc.firestoreData

        #expect(data["id"] as? String == "test-id")
        #expect(data["userId"] as? String == "user-123")
        #expect(data["type"] as? String == "water")
        #expect(data["value"] as? String == "12345")
        #expect(data["deviceId"] as? String == "device-abc")
        #expect(data["version"] as? Int64 == 1)
        #expect(data["deletedAt"] == nil)
        #expect(data["imagePath"] == nil)
    }

    @Test func firestoreDataIncludesOptionalFields() {
        let doc = MeterReadingDocument(
            id: "test-id",
            userId: "user-123",
            type: "electricity",
            value: "99999",
            date: Date(),
            createdAt: Date(),
            updatedAt: Date(),
            deletedAt: Date(),
            deviceId: "device-xyz",
            version: 5,
            imagePath: "users/user-123/images/test.jpg"
        )

        let data = doc.firestoreData

        #expect(data["deletedAt"] != nil)
        #expect(data["imagePath"] as? String == "users/user-123/images/test.jpg")
    }

    @Test func fromFirestoreDataRoundTrip() {
        let now = Date(timeIntervalSince1970: 1700000000)
        let input: [String: Any] = [
            "id": "round-trip-id",
            "userId": "user-abc",
            "type": "gas",
            "value": "55555",
            "date": now,
            "createdAt": now,
            "updatedAt": now,
            "deviceId": "device-rt",
            "version": Int64(2)
        ]

        let doc = MeterReadingDocument.from(firestoreData: input)
        #expect(doc != nil)
        #expect(doc?.id == "round-trip-id")
        #expect(doc?.type == "gas")
        #expect(doc?.version == 2)
    }

    @Test func fromFirestoreDataMissingRequiredFieldsReturnsNil() {
        let input: [String: Any] = [
            "id": "incomplete",
            "userId": "user-abc"
            // missing type, value, deviceId, version
        ]

        let doc = MeterReadingDocument.from(firestoreData: input)
        #expect(doc == nil)
    }
}
