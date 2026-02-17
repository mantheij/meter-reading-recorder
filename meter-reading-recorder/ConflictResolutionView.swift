import SwiftUI

struct ConflictResolutionView: View {
    @ObservedObject var reading: MeterReading
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: AppTheme.Spacing.lg) {
                Text(L10n.conflictDetected)
                    .font(.title2.bold())

                Text(L10n.conflictMessage)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                HStack(spacing: AppTheme.Spacing.md) {
                    // Local version
                    VStack(spacing: AppTheme.Spacing.sm) {
                        Text(L10n.yourVersion)
                            .font(.caption.bold())
                            .foregroundColor(AppTheme.accentPrimary)

                        Text(reading.value ?? "—")
                            .font(.title3.bold())

                        Text(reading.date ?? Date(), style: .date)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(AppTheme.accentPrimary.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.md))

                    // Cloud version
                    if let conflict = reading.decodedConflictData {
                        VStack(spacing: AppTheme.Spacing.sm) {
                            Text(L10n.cloudVersion)
                                .font(.caption.bold())
                                .foregroundColor(AppTheme.syncConflict)

                            Text(conflict.value)
                                .font(.title3.bold())

                            Text(conflict.date, style: .date)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(AppTheme.syncConflict.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.md))
                    }
                }
                .padding(.horizontal)

                Spacer()

                VStack(spacing: AppTheme.Spacing.sm) {
                    Button(action: {
                        SyncService.shared.resolveConflictKeepLocal(reading)
                        dismiss()
                    }) {
                        Label(L10n.keepMine, systemImage: "iphone")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(AppTheme.accentPrimary)
                            .foregroundColor(.white)
                            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.md))
                    }

                    Button(action: {
                        SyncService.shared.resolveConflictAcceptRemote(reading)
                        dismiss()
                    }) {
                        Label(L10n.acceptRemote, systemImage: "icloud.and.arrow.down")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .foregroundColor(AppTheme.accentPrimary)
                            .background(AppTheme.accentPrimary.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.md))
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, AppTheme.Spacing.lg)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.cancel) { dismiss() }
                }
            }
        }
    }
}
