import SwiftUI

// MARK: - Language Environment Key

private struct AppLanguageKey: EnvironmentKey {
    static let defaultValue: String = AppLanguage.de.rawValue
}

extension EnvironmentValues {
    var appLanguage: String {
        get { self[AppLanguageKey.self] }
        set { self[AppLanguageKey.self] = newValue }
    }
}

// MARK: - App Language

enum AppLanguage: String, CaseIterable {
    case de, en

    var displayName: String {
        switch self {
        case .de: return "Deutsch"
        case .en: return "English"
        }
    }
}

// MARK: - Localized Strings

struct L10n {
    private static var current: AppLanguage {
        AppLanguage(rawValue: UserDefaults.standard.string(forKey: "appLanguage") ?? "de") ?? .de
    }

    private static func s(_ de: String, _ en: String) -> String {
        current == .de ? de : en
    }

    // MARK: General
    static var cancel: String { s("Abbrechen", "Cancel") }
    static var confirm: String { s("Bestätigen", "Confirm") }
    static var save: String { s("Speichern", "Save") }
    static var delete: String { s("Löschen", "Delete") }
    static var next: String { s("Weiter", "Next") }
    static var close: String { s("Schließen", "Close") }
    static var edit: String { s("Bearbeiten", "Edit") }
    static var apply: String { s("Übernehmen", "Apply") }

    // MARK: Main Screen
    static var meterReadings: String { s("Zählerstände", "Meter Readings") }
    static var captureMeterReading: String { s("Zählerstand erfassen", "Capture Meter Reading") }

    // MARK: OCR Alerts
    static var recognitionSuccessful: String { s("Erkennung erfolgreich", "Recognition Successful") }
    static var retakePhoto: String { s("Erneut fotografieren", "Retake Photo") }
    static func recognizedNumber(_ value: String) -> String {
        s("Erkannte Zahl: \(value)\nBitte bestätigen.", "Recognized number: \(value)\nPlease confirm.")
    }
    static var recognizedNumberUnavailable: String {
        s("Erkannte Zahl ist nicht verfügbar.", "Recognized number is not available.")
    }
    static var recognitionFailed: String { s("Erkennung fehlgeschlagen", "Recognition Failed") }
    static var recognitionFailedMessage: String {
        s("Die Zahl konnte nicht erkannt werden. Bitte erneut fotografieren.",
          "The number could not be recognized. Please retake the photo.")
    }

    // MARK: Form Sheets
    static var editRecognizedValue: String { s("Erkannten Wert bearbeiten", "Edit Recognized Value") }
    static var manualEntry: String { s("Manuell eingeben", "Manual Entry") }
    static var editMeterReading: String { s("Zählerstand bearbeiten", "Edit Meter Reading") }
    static var meterReadingPlaceholder: String { s("Zählerstand", "Meter Reading") }
    static var date: String { s("Datum", "Date") }
    static var noImageAvailable: String { s("Kein Bild vorhanden", "No image available") }
    static var noImageToShow: String { s("Kein Bild zum Anzeigen", "No image to display") }

    // MARK: Meter Type Selection
    static var selectMeterType: String { s("Zählertyp auswählen", "Select Meter Type") }

    // MARK: Meter Types
    static var water: String { s("Wasser", "Water") }
    static var electricity: String { s("Strom", "Electricity") }
    static var gas: String { s("Gas", "Gas") }

    // MARK: Readings List
    static var noReadings: String { s("Keine Zählerstände", "No Readings") }
    static func emptyStateSubtitle(_ typeName: String) -> String {
        s("Erfasse deinen ersten \(typeName)-Zählerstand über die Kamera oder manuelle Eingabe.",
          "Capture your first \(typeName) meter reading via camera or manual entry.")
    }
    static var deleteEntry: String { s("Eintrag löschen?", "Delete Entry?") }
    static var deleteEntryMessage: String {
        s("Möchtest du diesen Zählerstand wirklich löschen?",
          "Do you really want to delete this meter reading?")
    }

    // MARK: Sidebar
    static var settings: String { s("Einstellungen", "Settings") }
    static var visualization: String { s("Visualisierung", "Visualization") }

    // MARK: Settings
    static var appearance: String { s("Erscheinungsbild", "Appearance") }
    static var language: String { s("Sprache", "Language") }
    static var appearanceSystem: String { s("System", "System") }
    static var appearanceLight: String { s("Hell", "Light") }
    static var appearanceDark: String { s("Dunkel", "Dark") }

    // MARK: Authentication
    static var login: String { s("Anmelden", "Login") }
    static var logout: String { s("Abmelden", "Logout") }
    static var account: String { s("Konto", "Account") }
    static var email: String { s("E-Mail", "Email") }
    static var password: String { s("Passwort", "Password") }
    static var signIn: String { s("Anmelden", "Sign In") }
    static var createAccount: String { s("Konto erstellen", "Create Account") }
    static var signInWithApple: String { s("Mit Apple anmelden", "Sign in with Apple") }
    static var signInWithGoogle: String { s("Mit Google anmelden", "Sign in with Google") }
    static var orSeparator: String { s("oder", "or") }
    static var alreadyHaveAccount: String { s("Bereits ein Konto?", "Already have an account?") }
    static var noAccountYet: String { s("Noch kein Konto?", "No account yet?") }
    static var logoutConfirmation: String {
        s("Möchtest du dich wirklich abmelden?",
          "Do you really want to sign out?")
    }
    static var loginSuccessful: String { s("Anmeldung erfolgreich", "Login successful") }
    static var signedInAs: String { s("Angemeldet als", "Signed in as") }
    static var provider: String { s("Anbieter", "Provider") }

    // Auth Errors
    static var authErrorInvalidEmail: String { s("Ungültige E-Mail-Adresse.", "Invalid email address.") }
    static var authErrorWeakPassword: String { s("Passwort muss mindestens 8 Zeichen lang sein.", "Password must be at least 8 characters.") }
    static var authErrorEmailInUse: String { s("Diese E-Mail-Adresse wird bereits verwendet.", "This email address is already in use.") }
    static var authErrorWrongCredentials: String { s("E-Mail oder Passwort ist falsch.", "Email or password is incorrect.") }
    static var authErrorNetwork: String { s("Netzwerkfehler. Bitte überprüfe deine Verbindung.", "Network error. Please check your connection.") }
    static func authErrorRateLimited(_ seconds: Int) -> String {
        s("Zu viele Versuche. Bitte warte \(seconds) Sekunden.",
          "Too many attempts. Please wait \(seconds) seconds.")
    }
    static var authErrorCancelled: String { s("Anmeldung abgebrochen.", "Sign-in was cancelled.") }
    static var authErrorUnknown: String { s("Ein Fehler ist aufgetreten. Bitte versuche es erneut.", "An error occurred. Please try again.") }

    // MARK: Visualization
    static var consumption: String { s("Verbrauch", "Consumption") }
    static var week: String { s("Woche", "Week") }
    static var month: String { s("Monat", "Month") }
    static var threeMonths: String { s("3M", "3M") }
    static var sixMonths: String { s("6M", "6M") }
    static var twelveMonths: String { s("12M", "12M") }
    static var allTime: String { s("Gesamt", "All") }
    static var total: String { s("Gesamt", "Total") }
    static var averagePer: String { s("Ø pro", "Avg per") }
    static var trend: String { s("Trend", "Trend") }
    static var noDataForVisualization: String { s("Nicht genug Daten", "Not enough data") }
    static var noDataForVisualizationSubtitle: String {
        s("Erfasse mindestens zwei Zählerstände eines Typs, um den Verbrauch zu berechnen.",
          "Record at least two meter readings of one type to calculate consumption.")
    }
    static var period: String { s("Zeitraum", "Period") }
    static var vsLastPeriod: String { s("ggü. Vorperiode", "vs last period") }
}
