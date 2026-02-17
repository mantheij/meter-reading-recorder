import SwiftUI

struct SyncStatusIndicator: View {
    let status: SyncStatus

    var body: some View {
        Image(systemName: status.iconName)
            .font(.caption2)
            .foregroundColor(status.displayColor)
    }
}
