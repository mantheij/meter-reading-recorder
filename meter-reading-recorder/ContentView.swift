import SwiftUI
import Vision
import AVFoundation
import CoreData

// MARK: - Content View
struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext

    @State private var showCamera = false
    @State private var recognizedValue: String? = nil
    @State private var capturedImage: UIImage? = nil
    @State private var showTypeSelector = false
    
    // Accent colors array for cycling
    private let accentColors: [Color] = [.meterAccent1, .meterAccent2, .meterAccent3, .meterAccent4]
    
    var body: some View {
        NavigationView {
            VStack {
                List {
                    ForEach(Array(MeterType.allCases.enumerated()), id: \.element) { index, type in
                        NavigationLink(destination: MeterTypeReadingsView(type: type)) {
                            Text(type.displayName)
                                .foregroundColor(.black) // Basic text in black
                                .font(.headline) // Prominent headline font
                                .padding(.vertical, 8)
                                .padding(.leading, 12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(accentColors[index % accentColors.count].opacity(0.15))
                                .cornerRadius(8)
                        }
                        .listRowBackground(Color.clear) // Clear default listrow background to show custom bg
                    }
                }
                .navigationTitle("Zählerstände")
                
                Button(action: { showCamera = true }) {
                    Label("Zählerstand erfassen", systemImage: "camera.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.meterAccent3) // Use meterAccent3 as background for main button
                        .foregroundColor(.white) // White text for contrast
                        .cornerRadius(10)
                }
                .padding()
            }
            .sheet(isPresented: $showCamera) {
                CameraView { image in
                    processImage(image)
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
                showTypeSelector = true
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
        
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try? handler.perform([request])
    }
    
    func extractNumbers(from strings: [String]) -> String? {
        for string in strings {
            let numbers = string.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
            if numbers.count >= 4 { // Mindestens 4-stellige Zahl
                return numbers
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
    @FetchRequest var readings: FetchedResults<MeterReading>
    
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
                ReadingRow(reading: reading)
            }
        }
        .navigationTitle(type.displayName)
    }
}

// MARK: - Reading Row
struct ReadingRow: View {
    let reading: MeterReading
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(reading.value ?? "N/A")
                    .font(.headline)
                    .foregroundColor(.black) // Basic value text in black
                
                Text(reading.date ?? Date(), style: .date)
                    .font(.caption)
                    .foregroundColor(Color.meterAccent1.opacity(0.7)) // Subtle accent color for date
            }
            Spacer()
            if let imageData = reading.imageData, let image = UIImage(data: imageData) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 60, height: 60)
                    .cornerRadius(8)
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
}

