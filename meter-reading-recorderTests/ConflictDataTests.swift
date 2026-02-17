import Testing
import Foundation
@testable import meter_reading_recorder

struct ConflictDataTests {

    @Test func encodingAndDecoding() throws {
        let original = ConflictData(
            value: "12345",
            date: Date(timeIntervalSince1970: 1000000),
            updatedAt: Date(timeIntervalSince1970: 2000000),
            deviceId: "device-abc",
            version: 3,
            imagePath: "users/uid/images/test.jpg"
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ConflictData.self, from: data)

        #expect(decoded.value == "12345")
        #expect(decoded.deviceId == "device-abc")
        #expect(decoded.version == 3)
        #expect(decoded.imagePath == "users/uid/images/test.jpg")
    }

    @Test func decodingWithNilImagePath() throws {
        let original = ConflictData(
            value: "99999",
            date: Date(),
            updatedAt: Date(),
            deviceId: "device-xyz",
            version: 1,
            imagePath: nil
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ConflictData.self, from: data)

        #expect(decoded.value == "99999")
        #expect(decoded.imagePath == nil)
    }
}
