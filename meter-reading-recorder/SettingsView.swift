import SwiftUI

struct SettingsView: View {
    @AppStorage("appAppearance") private var appearanceRaw: String = AppAppearance.system.rawValue
    @AppStorage("appLanguage") private var languageRaw: String = AppLanguage.de.rawValue

    private var appearance: AppAppearance {
        get { AppAppearance(rawValue: appearanceRaw) ?? .system }
    }

    private var language: AppLanguage {
        get { AppLanguage(rawValue: languageRaw) ?? .de }
    }

    var body: some View {
        Form {
            Section(header: Text(L10n.appearance)) {
                Picker(L10n.appearance, selection: $appearanceRaw) {
                    ForEach(AppAppearance.allCases, id: \.rawValue) { option in
                        Text(option.displayName).tag(option.rawValue)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }

            Section(header: Text(L10n.language)) {
                Picker(L10n.language, selection: $languageRaw) {
                    ForEach(AppLanguage.allCases, id: \.rawValue) { lang in
                        Text(lang.displayName).tag(lang.rawValue)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }
        }
        .navigationTitle(L10n.settings)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(L10n.settings)
                    .font(.title2)
                    .bold()
            }
        }
    }
}
