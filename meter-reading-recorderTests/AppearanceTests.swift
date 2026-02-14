import Testing
import SwiftUI
@testable import meter_reading_recorder

struct AppearanceTests {

    @Test func systemColorSchemeIsNil() {
        #expect(AppAppearance.system.colorScheme == nil)
    }

    @Test func lightColorScheme() {
        #expect(AppAppearance.light.colorScheme == .light)
    }

    @Test func darkColorScheme() {
        #expect(AppAppearance.dark.colorScheme == .dark)
    }

    @Test func allCasesCount() {
        #expect(AppAppearance.allCases.count == 3)
    }

    @Test func rawValues() {
        #expect(AppAppearance.system.rawValue == "system")
        #expect(AppAppearance.light.rawValue == "light")
        #expect(AppAppearance.dark.rawValue == "dark")
    }

    @Test func displayNamesNotEmpty() {
        for appearance in AppAppearance.allCases {
            #expect(!appearance.displayName.isEmpty)
        }
    }
}
