import Vision
import UIKit

struct OCRService {
    static func recognizeText(in image: UIImage, completion: @escaping (String?) -> Void) {
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

            let numbers = extractNumbers(from: recognizedStrings)
            completion(numbers)
        }

        request.recognitionLevel = .accurate
        request.recognitionLanguages = ["de-DE", "en-US"]

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try? handler.perform([request])
    }

    static func extractNumbers(from strings: [String]) -> String? {
        let pattern = "^\\d{1,}[.,]?\\d{0,}$"
        for string in strings {
            let allowed = string.components(separatedBy: CharacterSet(charactersIn: "0123456789.,").inverted).joined()
            var normalized = allowed.replacingOccurrences(of: ",", with: ".")
            if let firstDotRange = normalized.range(of: ".") {
                let before = normalized[..<firstDotRange.upperBound]
                let after = normalized[firstDotRange.upperBound...].replacingOccurrences(of: ".", with: "")
                normalized = String(before + after)
            }
            let digitsOnly = normalized.replacingOccurrences(of: ".", with: "")
            if digitsOnly.count >= 4, normalized.range(of: pattern, options: .regularExpression) != nil {
                return normalized
            }
        }
        return nil
    }
}
