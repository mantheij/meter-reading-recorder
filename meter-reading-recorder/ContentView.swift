import SwiftUI
import Vision
import AVFoundation
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
    
    // Accent colors array for cycling
    private let accentColors: [Color] = [.meterAccent1, .meterAccent2, .meterAccent3, .meterAccent4]
    // Dark mode accent colors for higher contrast
    private let darkAccentColors: [Color] = [.darkMeterAccent1, .darkMeterAccent2, .darkMeterAccent3, .darkMeterAccent4]
    
    var body: some View {
        NavigationView {
            VStack {
                List {
                    ForEach(Array(MeterType.allCases.enumerated()), id: \.element) { index, type in
                        NavigationLink(destination: MeterTypeReadingsView(type: type)) {
                            Text(type.displayName)
                                .foregroundColor(colorScheme == .dark ? .white : .black) // Adapt text color for dark mode
                                .font(.headline) // Prominent headline font
                                .padding(.vertical, 8)
                                .padding(.leading, 12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background((colorScheme == .dark ? darkAccentColors[index % darkAccentColors.count] : accentColors[index % accentColors.count]).opacity(colorScheme == .dark ? 0.35 : 0.15))
                                .cornerRadius(8)
                        }
                        .listRowBackground(Color.clear) // Clear default listrow background to show custom bg
                    }
                }
                .navigationBarTitleDisplayMode(.large)
                .toolbar {
                    ToolbarItem(placement: .principal) {
                        Text("Zählerstände")
                            .font(.largeTitle).bold()
                            .foregroundColor(colorScheme == .dark ? .white : .primary)
                            .offset(y: 24)
                    }
                }
                
                Button(action: { showCamera = true }) {
                    Label("Zählerstand erfassen", systemImage: "camera.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(colorScheme == .dark ? Color.darkMeterAccentPrimary : Color.meterAccent3) // Use dark mode color in dark mode
                        .foregroundColor(.white) // White text for contrast
                        .cornerRadius(10)
                }
                .padding()
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
                                // Allow digits and a single decimal separator (comma or dot), normalize to dot
                                var filtered = editedValue.trimmingCharacters(in: .whitespacesAndNewlines)
                                filtered = filtered.replacingOccurrences(of: ",", with: ".")
                                // Keep only digits and dots
                                filtered = filtered.components(separatedBy: CharacterSet(charactersIn: "0123456789.").inverted).joined()
                                // Ensure at most one dot
                                if let firstDot = filtered.firstIndex(of: ".") {
                                    let after = filtered[filtered.index(after: firstDot)...].replacingOccurrences(of: ".", with: "")
                                    filtered = String(filtered[..<filtered.index(after: firstDot)]) + after
                                }
                                let digitsOnly = filtered.replacingOccurrences(of: ".", with: "")
                                if !digitsOnly.isEmpty {
                                    recognizedValue = filtered
                                    showEditSheet = false
                                    showTypeSelector = true
                                } else {
                                    // keep sheet open for correction
                                }
                            }
                        }
                    }
                }
            }
            .confirmationDialog("Zählertyp auswählen", isPresented: $showTypeSelector, titleVisibility: .visible) {
                ForEach(MeterType.allCases, id: \.self) { type in
                    Button(type.displayName) {
                        if let value = recognizedValue, let image = capturedImage {
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
    }
    
    func processImage(_ image: UIImage) {
        // OCR durchführen und nur Zahlen extrahieren
        recognizeText(in: image) { recognizedNumber in
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
    
    func recognizeText(in image: UIImage, completion: @escaping (String?) -> Void) {
        guard let cgImage = image.cgImage else {
            completion(nil)
            return
        }
        
        let request = VNRecognizeTextRequest { request, error in
            guard let observations = request.results as? [VNRecognizedTextObservation] else {
                completion(nil)
                return
            }
            
            let recognizedStrings = observations.compactMap { observation in
                observation.topCandidates(1).first?.string
            }
            
            // Nur Zahlen extrahieren, ohne Zählertyp-Erkennung
            let numbers = extractNumbers(from: recognizedStrings)
            
            completion(numbers)
        }
        
        request.recognitionLevel = .accurate
        request.recognitionLanguages = ["de-DE", "en-US"]
        
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try? handler.perform([request])
    }
    
    func extractNumbers(from strings: [String]) -> String? {
        // Allow digits with a single decimal separator (comma or dot)
        let pattern = "^\\d{1,}[.,]?\\d{0,}$"
        for string in strings {
            // Remove spaces and non relevant characters except digits, comma and dot
            let allowed = string.components(separatedBy: CharacterSet(charactersIn: "0123456789.,").inverted).joined()
            // Normalize multiple separators and keep only the first one
            var normalized = allowed.replacingOccurrences(of: ",", with: ".")
            // If there are multiple dots, keep first and remove the rest
            if let firstDotRange = normalized.range(of: ".") {
                let before = normalized[..<firstDotRange.upperBound]
                let after = normalized[firstDotRange.upperBound...].replacingOccurrences(of: ".", with: "")
                normalized = String(before + after)
            }
            // Validate against pattern and require at least 4 characters ignoring the dot
            let digitsOnly = normalized.replacingOccurrences(of: ".", with: "")
            if digitsOnly.count >= 4, normalized.range(of: pattern, options: .regularExpression) != nil {
                return normalized
            }
        }
        return nil
    }
    
    func saveReading(value: String, type: MeterType, image: UIImage) {
        let newReading = MeterReading(context: viewContext)
        newReading.id = UUID()
        newReading.value = value
        newReading.meterType = type.rawValue
        newReading.date = Date()
        newReading.imageData = image.jpegData(compressionQuality: 0.7)
        
        try? viewContext.save()
    }
}

// MARK: - MeterTypeReadingsView
struct MeterTypeReadingsView: View {
    let type: MeterType
    
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.colorScheme) private var colorScheme
    @FetchRequest var readings: FetchedResults<MeterReading>
    
    @State private var showDeleteConfirmation: Bool = false
    @State private var pendingDeletion: MeterReading? = nil
    @State private var showEditSheet: Bool = false
    @State private var editingReading: MeterReading? = nil
    @State private var editedValue: String = ""

    @State private var showImageFullscreen: Bool = false
    @State private var fullscreenImage: UIImage? = nil
    
    init(type: MeterType) {
        self.type = type
        _readings = FetchRequest<MeterReading>(
            sortDescriptors: [NSSortDescriptor(keyPath: \MeterReading.date, ascending: false)],
            predicate: NSPredicate(format: "meterType == %@", type.rawValue),
            animation: .default
        )
    }
    
    var body: some View {
        List {
            ForEach(readings) { reading in
                ReadingRow(reading: reading, onImageTap: { img in
                    fullscreenImage = img
                    showImageFullscreen = true
                })
                .contentShape(Rectangle())
                .onTapGesture {
                    editingReading = reading
                    editedValue = reading.value ?? ""
                    showEditSheet = true
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) {
                        pendingDeletion = reading
                        showDeleteConfirmation = true
                    } label: {
                        Label("Löschen", systemImage: "trash")
                    }
                }
            }
        }
        .alert("Eintrag löschen?", isPresented: $showDeleteConfirmation) {
            Button("Abbrechen", role: .cancel) {
                pendingDeletion = nil
            }
            Button("Löschen", role: .destructive) {
                if let toDelete = pendingDeletion {
                    viewContext.delete(toDelete)
                    try? viewContext.save()
                    pendingDeletion = nil
                }
            }
        } message: {
            Text("Möchtest du diesen Zählerstand wirklich löschen?")
        }
        .sheet(isPresented: $showEditSheet) {
            NavigationView {
                VStack(spacing: 16) {
                    Text("Zählerstand bearbeiten")
                        .font(.headline)
                    
                    if let data = editingReading?.imageData, let uiImg = UIImage(data: data) {
                        Image(uiImage: uiImg)
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
                            editingReading = nil
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Speichern") {
                            // Normalize and validate input similar to capture edit flow
                            var filtered = editedValue.trimmingCharacters(in: .whitespacesAndNewlines)
                            filtered = filtered.replacingOccurrences(of: ",", with: ".")
                            filtered = filtered.components(separatedBy: CharacterSet(charactersIn: "0123456789.").inverted).joined()
                            if let firstDot = filtered.firstIndex(of: ".") {
                                let after = filtered[filtered.index(after: firstDot)...].replacingOccurrences(of: ".", with: "")
                                filtered = String(filtered[..<filtered.index(after: firstDot)]) + after
                            }
                            let digitsOnly = filtered.replacingOccurrences(of: ".", with: "")
                            if !digitsOnly.isEmpty, let editing = editingReading {
                                editing.value = filtered
                                try? viewContext.save()
                                showEditSheet = false
                                editingReading = nil
                            } else {
                                // keep sheet open for correction
                            }
                        }
                    }
                }
            }
        }
        .fullScreenCover(isPresented: $showImageFullscreen) {
            ZStack {
                Color.black.ignoresSafeArea()
                VStack {
                    Spacer()
                    if let img = fullscreenImage {
                        Image(uiImage: img)
                            .resizable()
                            .scaledToFit()
                            .padding()
                    } else {
                        // Placeholder if image is unexpectedly nil
                        ProgressView()
                            .tint(.white)
                    }
                    Spacer()
                    Button(action: { showImageFullscreen = false }) {
                        Label("Schließen", systemImage: "xmark.circle.fill")
                            .font(.title2)
                            .padding()
                            .foregroundColor(.white)
                    }
                }
            }
        }
        .navigationTitle(type.displayName)
    }
}

// MARK: - Reading Row
struct ReadingRow: View {
    @ObservedObject var reading: MeterReading
    var onImageTap: ((UIImage) -> Void)? = nil
    
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(reading.value ?? "N/A")
                    .font(.headline)
                    .foregroundColor(colorScheme == .dark ? .white : .black) // Adapt text color for dark mode
                
                Text(reading.date ?? Date(), style: .date)
                    .font(.caption)
                    .foregroundColor((colorScheme == .dark ? Color.darkMeterAccentSecondary : Color.meterAccent1).opacity(0.7)) // Subtle accent color for date
            }
            Spacer()
            if let imageData = reading.imageData, let image = UIImage(data: imageData) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 60, height: 60)
                    .cornerRadius(8)
                    .onTapGesture { onImageTap?(image) }
            }
        }
    }
}

// MARK: - Camera View
struct CameraView: UIViewControllerRepresentable {
    let onCapture: (UIImage) -> Void
    @Environment(\.presentationMode) var presentationMode
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.modalPresentationStyle = .fullScreen
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraView
        
        init(_ parent: CameraView) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.onCapture(image)
            }
            parent.presentationMode.wrappedValue.dismiss()
        }
    }
}

// MARK: - Meter Type Enum
enum MeterType: String, CaseIterable {
    case water = "water"
    case electricity = "electricity"
    case gas = "gas"
    
    var displayName: String {
        switch self {
        case .water: return "Wasser"
        case .electricity: return "Strom"
        case .gas: return "Gas"
        }
    }
}
// MARK: - Color Extension for Meter Accent Colors
extension Color {
    static let meterAccent1 = Color(red: 0/255, green: 84/255, blue: 97/255) // #005461
    static let meterAccent2 = Color(red: 12/255, green: 119/255, blue: 121/255) // #0C7779
    static let meterAccent3 = Color(red: 36/255, green: 158/255, blue: 148/255) // #249E94
    static let meterAccent4 = Color(red: 59/255, green: 193/255, blue: 168/255) // #3BC1A8

    // Dark mode accent palette (higher contrast against dark backgrounds)
    static let darkMeterAccentPrimary = Color(red: 0/255, green: 180/255, blue: 190/255) // teal-cyan, bright for buttons
    static let darkMeterAccentSecondary = Color(red: 140/255, green: 220/255, blue: 210/255) // softer accent for text/details
    static let darkMeterAccent1 = Color(red: 20/255, green: 110/255, blue: 120/255)
    static let darkMeterAccent2 = Color(red: 16/255, green: 140/255, blue: 150/255)
    static let darkMeterAccent3 = Color(red: 0/255, green: 170/255, blue: 160/255)
    static let darkMeterAccent4 = Color(red: 0/255, green: 200/255, blue: 180/255)
}

