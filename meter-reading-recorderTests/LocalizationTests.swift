import Testing
import Foundation
@testable import meter_reading_recorder

// Tests that mutate UserDefaults must run serially to avoid race conditions.
@Suite(.serialized)
struct LocalizationTests {

    // MARK: - AppLanguage enum

    @Test func displayNameDeutsch() {
        #expect(AppLanguage.de.displayName == "Deutsch")
    }

    @Test func displayNameEnglish() {
        #expect(AppLanguage.en.displayName == "English")
    }

    @Test func allCasesCount() {
        #expect(AppLanguage.allCases.count == 2)
    }

    @Test func rawValues() {
        #expect(AppLanguage.de.rawValue == "de")
        #expect(AppLanguage.en.rawValue == "en")
    }

    // MARK: - L10n strings

    @Test func germanStringsWhenLanguageIsDe() {
        UserDefaults.standard.set("de", forKey: "appLanguage")
        UserDefaults.standard.synchronize()
        #expect(L10n.cancel == "Abbrechen")
        #expect(L10n.save == "Speichern")
        #expect(L10n.meterReadings == "Zählerstände")
        #expect(L10n.settings == "Einstellungen")
    }

    @Test func englishStringsWhenLanguageIsEn() {
        UserDefaults.standard.set("en", forKey: "appLanguage")
        UserDefaults.standard.synchronize()
        #expect(L10n.cancel == "Cancel")
        #expect(L10n.save == "Save")
        #expect(L10n.meterReadings == "Meter Readings")
        #expect(L10n.settings == "Settings")
    }

    @Test func defaultLanguageIsGerman() {
        UserDefaults.standard.removeObject(forKey: "appLanguage")
        UserDefaults.standard.synchronize()
        #expect(L10n.cancel == "Abbrechen")
        #expect(L10n.meterReadings == "Zählerstände")
    }

    @Test func meterTypeNamesLocalized() {
        UserDefaults.standard.set("en", forKey: "appLanguage")
        UserDefaults.standard.synchronize()
        #expect(L10n.water == "Water")
        #expect(L10n.electricity == "Electricity")
        #expect(L10n.gas == "Gas")
    }

    @Test func recognizedNumberFormatted() {
        UserDefaults.standard.set("de", forKey: "appLanguage")
        UserDefaults.standard.synchronize()
        let result = L10n.recognizedNumber("12345")
        #expect(result.contains("12345"))
    }
}
