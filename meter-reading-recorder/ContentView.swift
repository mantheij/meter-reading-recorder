import SwiftUI
import Vision
import AVFoundation
import CoreData

// MARK: - Content View
struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \MeterReading.date, ascending: false)],
        animation: .default)
    private var readings: FetchedResults<MeterReading>
    
    @State private var showCamera = false
    @State private var selectedMeterType: MeterType?
    
    var body: some View {
        NavigationView {
            VStack {
                // Liste der Zählerstände
                List {
                    ForEach(MeterType.allCases, id: \.self) { type in
                        Section(header: Text(type.displayName)) {
                            ForEach(readings.filter { $0.meterType == type.rawValue }) { reading in
                                ReadingRow(reading: reading)
                            }
                        }
                    }
                }
                
                // Kamera-Button
                Button(action: { showCamera = true }) {
                    Label("Zählerstand erfassen", systemImage: "camera.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .padding()
            }
            .navigationTitle("Zählerstände")
            .sheet(isPresented: $showCamera) {
                CameraView { image in
                    processImage(image)
                }
            }
        }
    }
    
    func processImage(_ image: UIImage) {
        // OCR durchführen
        recognizeText(in: image) { recognizedNumbers, detectedType in
            if let numbers = recognizedNumbers, let type = detectedType {
                saveReading(value: numbers, type: type, image: image)
            }
        }
    }
    
    func recognizeText(in image: UIImage, completion: @escaping (String?, MeterType?) -> Void) {
        guard let cgImage = image.cgImage else {
            completion(nil, nil)
            return
        }
        
        let request = VNRecognizeTextRequest { request, error in
            guard let observations = request.results as? [VNRecognizedTextObservation] else {
                completion(nil, nil)
                return
            }
            
            let recognizedStrings = observations.compactMap { observation in
                observation.topCandidates(1).first?.string
            }
            
            // Extrahiere Zahlen und erkenne Zählertyp
            let numbers = extractNumbers(from: recognizedStrings)
            let meterType = detectMeterType(from: recognizedStrings)
            
            completion(numbers, meterType)
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
    
    func detectMeterType(from strings: [String]) -> MeterType? {
        let combinedText = strings.joined(separator: " ").lowercased()
        
        if combinedText.contains("wasser") || combinedText.contains("water") {
            return .water
        } else if combinedText.contains("strom") || combinedText.contains("electric") || combinedText.contains("kwh") {
            return .electricity
        } else if combinedText.contains("gas") {
            return .gas
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

// MARK: - Reading Row
struct ReadingRow: View {
    let reading: MeterReading
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(reading.value ?? "N/A")
                    .font(.headline)
                Text(reading.date ?? Date(), style: .date)
                    .font(.caption)
                    .foregroundColor(.gray)
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
