import SwiftUI

struct SyncBanner: View {
    @ObservedObject var syncService: SyncService
    @ObservedObject var networkMonitor: NetworkMonitor

    var body: some View {
        Group {
            if !networkMonitor.isConnected {
                bannerContent(
                    icon: "wifi.slash",
                    text: L10n.offline,
                    color: AppTheme.syncError
                )
            } else if case .syncing = syncService.syncState {
                bannerContent(
                    icon: "arrow.triangle.2.circlepath",
                    text: L10n.syncing,
                    color: AppTheme.accentPrimary
                )
            } else if syncService.pendingCount > 0 {
                bannerContent(
                    icon: "arrow.triangle.2.circlepath",
                    text: L10n.pendingChanges(syncService.pendingCount),
                    color: AppTheme.syncPending
                )
            } else if case .error(let msg) = syncService.syncState {
                bannerContent(
                    icon: "exclamationmark.triangle",
                    text: "\(L10n.syncError): \(msg)",
                    color: AppTheme.syncError
                )
            }
        }
    }

    private func bannerContent(icon: String, text: String, color: Color) -> some View {
        HStack(spacing: AppTheme.Spacing.xs) {
            Image(systemName: icon)
                .font(.caption)
            Text(text)
                .font(.caption)
                .lineLimit(1)
        }
        .foregroundColor(color)
        .padding(.horizontal, AppTheme.Spacing.md)
        .padding(.vertical, AppTheme.Spacing.xs)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color.opacity(0.1))
    }
}
