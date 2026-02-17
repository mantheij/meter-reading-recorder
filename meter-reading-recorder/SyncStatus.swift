import SwiftUI

enum SyncStatus: Int16 {
    case pending = 0
    case synced = 1
    case error = 2
    case conflict = 3

    var iconName: String {
        switch self {
        case .pending: return "arrow.triangle.2.circlepath"
        case .synced: return "checkmark.icloud"
        case .error: return "exclamationmark.icloud"
        case .conflict: return "exclamationmark.triangle"
        }
    }

    var displayColor: Color {
        switch self {
        case .pending: return AppTheme.syncPending
        case .synced: return AppTheme.syncSynced
        case .error: return AppTheme.syncError
        case .conflict: return AppTheme.syncConflict
        }
    }
}
