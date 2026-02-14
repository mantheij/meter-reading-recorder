import SwiftUI
import CoreData

// MARK: - Content View
struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext

    @State private var showCamera = false
    @State private var recognizedValue: String? = nil
    @State private var capturedImage: UIImage? = nil
    @State private var showTypeSelector = false
    @State private var showSuccessAlert = false
    @State private var showErrorAlert = false
    @State private var showEditSheet = false
    @State private var editedValue: String = ""
    @State private var showManualEntry: Bool = false
    @State private var manualValue: String = ""
    @State private var showSidebar: Bool = false
    @State private var navigationPath = NavigationPath()

    var body: some View {
        ZStack(alignment: .leading) {
            NavigationStack(path: $navigationPath) {
                VStack {
                    MeterTypeListView()
                        .toolbar {
                            ToolbarItem(placement: .topBarLeading) {
                                Button(action: {
                                    withAnimation(.easeInOut(duration: 0.3)) {
                                        showSidebar = true
                                    }
                                }) {
                                    Image(systemName: "line.3.horizontal")
                                }
                            }
                            ToolbarItem(placement: .principal) {
                                Text("Zählerstände")
                                    .font(.largeTitle).bold()
                                    .foregroundColor(AppTheme.textPrimary)
                            }
                            ToolbarItem(placement: .topBarTrailing) {
                                Button(action: {
                                    manualValue = ""
                                    showManualEntry = true
                                }) {
                                    Image(systemName: "plus")
                                }
                            }
                        }

                    PrimaryButton(title: "Zählerstand erfassen", icon: "camera.fill") {
                        showCamera = true
                    }
                    .padding(AppTheme.Spacing.md)
                }
                .navigationDestination(for: SidebarDestination.self) { destination in
                    switch destination {
                    case .settings:
                        SettingsView()
                    case .visualization:
                        VisualizationView()
                    }
                }
            }
            SidebarView(showSidebar: $showSidebar) { destination in
                withAnimation(.easeInOut(duration: 0.3)) {
                    showSidebar = false
                }
                navigationPath.append(destination)
            }
            .allowsHitTesting(showSidebar)
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraView { image in
                processImage(image)
            }
            .ignoresSafeArea()
        }
        .alert("Erkennung erfolgreich", isPresented: $showSuccessAlert, actions: {
            Button("Bestätigen") {
                showTypeSelector = true
            }
            Button("Bearbeiten") {
                editedValue = recognizedValue ?? ""
                showEditSheet = true
            }
            Button("Erneut fotografieren", role: .cancel) {
                recognizedValue = nil
                capturedImage = nil
                showCamera = true
            }
        }, message: {
            if let value = recognizedValue {
                Text("Erkannte Zahl: \(value)\nBitte bestätigen.")
            } else {
                Text("Erkannte Zahl ist nicht verfügbar.")
            }
        })
        .alert("Erkennung fehlgeschlagen", isPresented: $showErrorAlert, actions: {
            Button("Erneut fotografieren") {
                recognizedValue = nil
                capturedImage = nil
                showCamera = true
            }
            Button("Abbrechen", role: .cancel) {}
        }, message: {
            Text("Die Zahl konnte nicht erkannt werden. Bitte erneut fotografieren.")
        })
        .sheet(isPresented: $showEditSheet) {
            MeterReadingFormSheet(
                title: "Erkannten Wert bearbeiten",
                image: capturedImage,
                value: $editedValue,
                confirmTitle: "Übernehmen",
                onCancel: { showEditSheet = false },
                onConfirm: {
                    if let sanitized = ValueFormatter.sanitizeMeterValue(editedValue) {
                        recognizedValue = sanitized
                        showEditSheet = false
                        showTypeSelector = true
                    }
                }
            )
        }
        .sheet(isPresented: $showManualEntry) {
            MeterReadingFormSheet(
                title: "Manuell eingeben",
                value: $manualValue,
                confirmTitle: "Weiter",
                onCancel: { showManualEntry = false },
                onConfirm: {
                    if let sanitized = ValueFormatter.sanitizeMeterValue(manualValue) {
                        recognizedValue = sanitized
                        capturedImage = nil
                        showManualEntry = false
                        showTypeSelector = true
                    }
                }
            )
        }
        .confirmationDialog("Zählertyp auswählen", isPresented: $showTypeSelector, titleVisibility: .visible) {
            ForEach(MeterType.allCases, id: \.self) { type in
                Button(type.displayName) {
                    if let value = recognizedValue {
                        let image = capturedImage ?? UIImage()
                        saveReading(value: value, type: type, image: image)
                    }
                    recognizedValue = nil
                    capturedImage = nil
                    showTypeSelector = false
                }
            }
            Button("Abbrechen", role: .cancel) {
                recognizedValue = nil
                capturedImage = nil
                showTypeSelector = false
            }
        }
    }

    func processImage(_ image: UIImage) {
        OCRService.recognizeText(in: image) { recognizedNumber in
            if let number = recognizedNumber {
                recognizedValue = number
                capturedImage = image
                showSuccessAlert = true
            } else {
                recognizedValue = nil
                capturedImage = nil
                showErrorAlert = true
            }
        }
    }

    func saveReading(value: String, type: MeterType, image: UIImage) {
        let newReading = MeterReading(context: viewContext)
        newReading.id = UUID()
        newReading.value = value
        newReading.meterType = type.rawValue
        newReading.date = Date()
        if let data = image.jpegData(compressionQuality: 0.7), data.count > 0 {
            newReading.imageData = data
        } else {
            newReading.imageData = nil
        }

        try? viewContext.save()
    }
}
