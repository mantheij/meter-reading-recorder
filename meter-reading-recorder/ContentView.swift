import SwiftUI
import CoreData

// MARK: - Content View
struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.appLanguage) private var appLanguage

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
    @State private var manualDate = Date()
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
                                Text(L10n.meterReadings)
                                    .font(.largeTitle).bold()
                                    .foregroundColor(AppTheme.textPrimary)
                            }
                            ToolbarItem(placement: .topBarTrailing) {
                                Button(action: {
                                    manualValue = ""
                                    manualDate = Date()
                                    showManualEntry = true
                                }) {
                                    Image(systemName: "plus")
                                }
                            }
                        }

                    PrimaryButton(title: L10n.captureMeterReading, icon: "camera.fill") {
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
        .alert(L10n.recognitionSuccessful, isPresented: $showSuccessAlert, actions: {
            Button(L10n.confirm) {
                showTypeSelector = true
            }
            Button(L10n.edit) {
                editedValue = recognizedValue ?? ""
                showEditSheet = true
            }
            Button(L10n.retakePhoto, role: .cancel) {
                recognizedValue = nil
                capturedImage = nil
                showCamera = true
            }
        }, message: {
            if let value = recognizedValue {
                Text(L10n.recognizedNumber(value))
            } else {
                Text(L10n.recognizedNumberUnavailable)
            }
        })
        .alert(L10n.recognitionFailed, isPresented: $showErrorAlert, actions: {
            Button(L10n.retakePhoto) {
                recognizedValue = nil
                capturedImage = nil
                showCamera = true
            }
            Button(L10n.cancel, role: .cancel) {}
        }, message: {
            Text(L10n.recognitionFailedMessage)
        })
        .sheet(isPresented: $showEditSheet) {
            MeterReadingFormSheet(
                title: L10n.editRecognizedValue,
                image: capturedImage,
                value: $editedValue,
                confirmTitle: L10n.apply,
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
                title: L10n.manualEntry,
                value: $manualValue,
                date: $manualDate,
                confirmTitle: L10n.next,
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
        .confirmationDialog(L10n.selectMeterType, isPresented: $showTypeSelector, titleVisibility: .visible) {
            ForEach(MeterType.allCases, id: \.self) { type in
                Button(type.displayName) {
                    if let value = recognizedValue {
                        let image = capturedImage ?? UIImage()
                        let date = capturedImage == nil ? manualDate : Date()
                        saveReading(value: value, type: type, image: image, date: date)
                    }
                    recognizedValue = nil
                    capturedImage = nil
                    showTypeSelector = false
                }
            }
            Button(L10n.cancel, role: .cancel) {
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

    func saveReading(value: String, type: MeterType, image: UIImage, date: Date = Date()) {
        let newReading = MeterReading(context: viewContext)
        newReading.id = UUID()
        newReading.value = value
        newReading.meterType = type.rawValue
        newReading.date = date
        if let data = image.jpegData(compressionQuality: 0.7), data.count > 0 {
            newReading.imageData = data
        } else {
            newReading.imageData = nil
        }

        try? viewContext.save()
    }
}
