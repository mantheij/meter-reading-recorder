import SwiftUI
import CoreData

// MARK: - Content View
struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.colorScheme) private var colorScheme

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
                    MeterTypeListView(colorScheme: colorScheme)
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
                                    .foregroundColor(colorScheme == .dark ? .white : .primary)
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

                    Button(action: { showCamera = true }) {
                        Label("Zählerstand erfassen", systemImage: "camera.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(colorScheme == .dark ? Color.darkMeterAccentPrimary : Color.meterAccent3)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    .padding()
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
            NavigationView {
                VStack(spacing: 16) {
                    Text("Erkannten Wert bearbeiten")
                        .font(.headline)

                    if let image = capturedImage {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 200)
                            .cornerRadius(8)
                            .padding(.horizontal)
                    }

                    TextField("Zählerstand", text: $editedValue)
                        .keyboardType(.decimalPad)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .padding(.horizontal)
                    Spacer()
                }
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Abbrechen") {
                            showEditSheet = false
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Übernehmen") {
                            if let sanitized = ValueFormatter.sanitizeMeterValue(editedValue) {
                                recognizedValue = sanitized
                                showEditSheet = false
                                showTypeSelector = true
                            }
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showManualEntry) {
            NavigationView {
                VStack(spacing: 16) {
                    Text("Manuell eingeben")
                        .font(.headline)

                    TextField("Zählerstand", text: $manualValue)
                        .keyboardType(.decimalPad)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .padding(.horizontal)
                    Spacer()
                }
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Abbrechen") {
                            showManualEntry = false
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Weiter") {
                            if let sanitized = ValueFormatter.sanitizeMeterValue(manualValue) {
                                recognizedValue = sanitized
                                capturedImage = nil
                                showManualEntry = false
                                showTypeSelector = true
                            }
                        }
                    }
                }
            }
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
