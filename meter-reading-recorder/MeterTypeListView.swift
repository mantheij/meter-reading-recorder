import SwiftUI
import CoreData

struct MeterTypeListView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.appLanguage) private var appLanguage
    @EnvironmentObject private var authService: AuthService

    var body: some View {
        ScrollView {
            VStack(spacing: AppTheme.Spacing.sm) {
                ForEach(Array(MeterType.allCases.enumerated()), id: \.element) { index, type in
                    MeterCard(
                        title: type.displayName,
                        iconName: type.iconName,
                        accentColor: AppTheme.meterAccent(for: index),
                        destination: AnyView(MeterTypeReadingsView(type: type))
                    )
                }
            }
            .padding(.horizontal, AppTheme.Spacing.md)
            .padding(.vertical, AppTheme.Spacing.xs)
        }
        .navigationBarTitleDisplayMode(.inline)
    }
}
