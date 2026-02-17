import SwiftUI

// MARK: - Design Tokens

enum AppTheme {

    // MARK: Spacing (4pt grid)
    enum Spacing {
        static let xs: CGFloat = 8
        static let sm: CGFloat = 12
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
    }

    // MARK: Corner Radii
    enum Radius {
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
    }

    // MARK: Adaptive Colors
    static let accentPrimary = Color(
        UIColor { $0.userInterfaceStyle == .dark
            ? UIColor(red: 0/255, green: 180/255, blue: 190/255, alpha: 1)
            : UIColor(red: 36/255, green: 158/255, blue: 148/255, alpha: 1)
        }
    )

    static let accentSecondary = Color(
        UIColor { $0.userInterfaceStyle == .dark
            ? UIColor(red: 140/255, green: 220/255, blue: 210/255, alpha: 1)
            : UIColor(red: 0/255, green: 84/255, blue: 97/255, alpha: 1)
        }
    )

    static let textPrimary = Color(
        UIColor { $0.userInterfaceStyle == .dark ? .white : .black }
    )

    static let surfaceBackground = Color(
        UIColor { $0.userInterfaceStyle == .dark ? .systemBackground : .white }
    )

    // MARK: Meter Accent (index-based)
    private static let lightAccents: [Color] = [.meterAccent1, .meterAccent2, .meterAccent3, .meterAccent4]
    private static let darkAccents: [Color] = [.darkMeterAccent1, .darkMeterAccent2, .darkMeterAccent3, .darkMeterAccent4]

    static func meterAccent(for index: Int) -> Color {
        Color(
            UIColor { tc in
                let palette = tc.userInterfaceStyle == .dark ? darkAccents : lightAccents
                return UIColor(palette[index % palette.count])
            }
        )
    }

    static var cardBackgroundOpacity: Double {
        // Evaluated once per draw — adapts via trait collection inside meterAccent
        // Light: subtle, Dark: stronger
        0.2
    }

    // MARK: Sync Status Colors
    static let syncPending = Color.orange
    static let syncSynced = Color.green
    static let syncError = Color.red
    static let syncConflict = Color.yellow

    // MARK: Shadows
    static let cardShadow = ShadowStyle.drop(color: .black.opacity(0.08), radius: 6, x: 0, y: 2)
    static let elevatedShadow = ShadowStyle.drop(color: .black.opacity(0.15), radius: 12, x: 4, y: 0)
}

// MARK: - Reusable Components

struct MeterCard: View {
    let title: String
    let iconName: String
    let accentColor: Color
    let destination: AnyView

    var body: some View {
        NavigationLink(destination: destination) {
            HStack(spacing: AppTheme.Spacing.sm) {
                Image(systemName: iconName)
                    .font(.title3.weight(.semibold))
                    .foregroundColor(.white)
                    .frame(width: 36, height: 36)
                    .background(accentColor)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.sm))

                Text(title)
                    .font(.headline)
                    .foregroundColor(AppTheme.textPrimary)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(AppTheme.accentSecondary.opacity(0.5))
            }
            .padding(AppTheme.Spacing.md)
            .background(accentColor.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.md))
            .shadow(color: .black.opacity(0.08), radius: 6, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }
}

struct PrimaryButton: View {
    let title: String
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding()
                .background(AppTheme.accentPrimary)
                .foregroundColor(.white)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.md))
        }
    }
}

struct MeterReadingFormSheet: View {
    let title: String
    let image: UIImage?
    @Binding var value: String
    private var dateBinding: Binding<Date>?
    let cancelTitle: String
    let confirmTitle: String
    let onCancel: () -> Void
    let onConfirm: () -> Void

    init(
        title: String,
        image: UIImage? = nil,
        value: Binding<String>,
        date: Binding<Date>? = nil,
        cancelTitle: String? = nil,
        confirmTitle: String? = nil,
        onCancel: @escaping () -> Void,
        onConfirm: @escaping () -> Void
    ) {
        self.title = title
        self.image = image
        self._value = value
        self.dateBinding = date
        self.cancelTitle = cancelTitle ?? L10n.cancel
        self.confirmTitle = confirmTitle ?? L10n.apply
        self.onCancel = onCancel
        self.onConfirm = onConfirm
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: AppTheme.Spacing.md) {
                Text(title)
                    .font(.headline)

                if let img = image {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 200)
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.sm))
                        .padding(.horizontal)
                } else if title == L10n.editMeterReading {
                    Text(L10n.noImageAvailable)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                }

                TextField(L10n.meterReadingPlaceholder, text: $value)
                    .keyboardType(.decimalPad)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding(.horizontal)

                if let dateBinding = dateBinding {
                    DatePicker(L10n.date, selection: dateBinding, displayedComponents: .date)
                        .datePickerStyle(.compact)
                        .padding(.horizontal)
                }

                Spacer()
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(cancelTitle, action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(confirmTitle, action: onConfirm)
                }
            }
        }
    }
}

struct EmptyStateView: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: AppTheme.Spacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundColor(AppTheme.accentSecondary.opacity(0.5))

            Text(title)
                .font(.headline)
                .foregroundColor(AppTheme.textPrimary)

            Text(subtitle)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(AppTheme.Spacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
