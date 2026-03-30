import Vision
import UIKit

struct OCRResult: Identifiable {
    let id = UUID()
    let text: String
    /// Vision-normalized bounding box (origin at bottom-left, values 0–1)
    let boundingBox: CGRect
    /// True when the text matches the strict meter-reading pattern (≥4 digits)
    let isBestCandidate: Bool
}

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

    /// Returns all OCR observations that contain at least 2 digits, with bounding boxes.
    /// Vision bounding boxes are computed in display orientation (orientation is passed in).
    static func recognizeAllCandidates(in image: UIImage, completion: @escaping ([OCRResult]) -> Void) {
        guard let cgImage = image.cgImage else {
            completion([])
            return
        }

        let orientation = CGImagePropertyOrientation(image.imageOrientation)
        let request = VNRecognizeTextRequest { request, _ in
            guard let observations = request.results as? [VNRecognizedTextObservation] else {
                completion([])
                return
            }

            let results: [OCRResult] = observations.compactMap { observation in
                guard let top = observation.topCandidates(1).first else { return nil }
                let text = top.string
                guard text.filter(\.isNumber).count >= 2 else { return nil }
                return OCRResult(
                    text: text,
                    boundingBox: observation.boundingBox,
                    isBestCandidate: isMeterReadingCandidate(text)
                )
            }

            completion(results)
        }

        request.recognitionLevel = .accurate
        request.recognitionLanguages = ["de-DE", "en-US"]

        let handler = VNImageRequestHandler(cgImage: cgImage, orientation: orientation, options: [:])
        try? handler.perform([request])
    }

    /// Strips non-numeric characters, normalises commas to dots, collapses multiple dots.
    static func extractNumericValue(from text: String) -> String {
        let allowed = text.components(separatedBy: CharacterSet(charactersIn: "0123456789.,").inverted).joined()
        var normalized = allowed.replacingOccurrences(of: ",", with: ".")
        if let firstDot = normalized.range(of: ".") {
            let before = normalized[..<firstDot.upperBound]
            let after = normalized[firstDot.upperBound...].replacingOccurrences(of: ".", with: "")
            normalized = String(before + after)
        }
        return normalized.isEmpty ? text : normalized
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

    private static func isMeterReadingCandidate(_ text: String) -> Bool {
        let allowed = text.components(separatedBy: CharacterSet(charactersIn: "0123456789.,").inverted).joined()
        var normalized = allowed.replacingOccurrences(of: ",", with: ".")
        if let firstDot = normalized.range(of: ".") {
            let before = normalized[..<firstDot.upperBound]
            let after = normalized[firstDot.upperBound...].replacingOccurrences(of: ".", with: "")
            normalized = String(before + after)
        }
        let digitsOnly = normalized.replacingOccurrences(of: ".", with: "")
        let pattern = "^\\d{1,}[.,]?\\d{0,}$"
        return digitsOnly.count >= 4 && normalized.range(of: pattern, options: .regularExpression) != nil
    }
}

// MARK: - UIImage.Orientation → CGImagePropertyOrientation

extension CGImagePropertyOrientation {
    init(_ uiOrientation: UIImage.Orientation) {
        switch uiOrientation {
        case .up:            self = .up
        case .upMirrored:    self = .upMirrored
        case .down:          self = .down
        case .downMirrored:  self = .downMirrored
        case .left:          self = .left
        case .leftMirrored:  self = .leftMirrored
        case .right:         self = .right
        case .rightMirrored: self = .rightMirrored
        @unknown default:    self = .up
        }
    }
}
