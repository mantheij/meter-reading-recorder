import Testing
import Foundation
import CoreData
@testable import meter_reading_recorder

struct SyncServiceTests {

    // MARK: - SyncStatus Tests

    @Test func syncStatusRawValues() {
        #expect(SyncStatus.pending.rawValue == 0)
        #expect(SyncStatus.synced.rawValue == 1)
        #expect(SyncStatus.error.rawValue == 2)
        #expect(SyncStatus.conflict.rawValue == 3)
    }

    @Test func syncStatusFromRawValue() {
        #expect(SyncStatus(rawValue: 0) == .pending)
        #expect(SyncStatus(rawValue: 1) == .synced)
        #expect(SyncStatus(rawValue: 2) == .error)
        #expect(SyncStatus(rawValue: 3) == .conflict)
        #expect(SyncStatus(rawValue: 99) == nil)
    }

    @Test func syncStatusIconNames() {
        #expect(!SyncStatus.pending.iconName.isEmpty)
        #expect(!SyncStatus.synced.iconName.isEmpty)
        #expect(!SyncStatus.error.iconName.isEmpty)
        #expect(!SyncStatus.conflict.iconName.isEmpty)
    }

    // MARK: - SyncState Tests

    @Test func syncStateEquality() {
        #expect(SyncState.idle == SyncState.idle)
        #expect(SyncState.syncing == SyncState.syncing)
        #expect(SyncState.offline == SyncState.offline)
        #expect(SyncState.error("test") == SyncState.error("test"))
        #expect(SyncState.error("a") != SyncState.error("b"))
        #expect(SyncState.idle != SyncState.syncing)
    }
}
