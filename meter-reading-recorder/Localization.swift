import SwiftUI

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
}
