import Testing
import Foundation
@testable import meter_reading_recorder

struct DeviceIdentifierTests {

    @Test func currentReturnsNonEmptyString() {
        let id = DeviceIdentifier.current
        #expect(!id.isEmpty)
    }

    @Test func currentIsIdempotent() {
        let first = DeviceIdentifier.current
        let second = DeviceIdentifier.current
        #expect(first == second)
    }

    @Test func currentIsValidUUID() {
        let id = DeviceIdentifier.current
        #expect(UUID(uuidString: id) != nil)
    }
}
