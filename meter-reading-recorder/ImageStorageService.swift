import UIKit

class ImageStorageService {
    static let shared = ImageStorageService()

    private let imagesDirectoryName = "Images"
    private let compressionQuality: CGFloat = 0.7

    private var imagesDirectory: URL {
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return documentsURL.appendingPathComponent(imagesDirectoryName)
    }

    private init() {
        createImagesDirectoryIfNeeded()
    }

    private func createImagesDirectoryIfNeeded() {
        let fm = FileManager.default
        if !fm.fileExists(atPath: imagesDirectory.path) {
            try? fm.createDirectory(at: imagesDirectory, withIntermediateDirectories: true)
        }
    }

    func saveImage(_ image: UIImage, id: UUID) -> String? {
        guard let data = image.jpegData(compressionQuality: compressionQuality), data.count > 0 else {
            return nil
        }
        let fileName = "\(id.uuidString).jpg"
        let fileURL = imagesDirectory.appendingPathComponent(fileName)
        do {
            try data.write(to: fileURL)
            return fileName
        } catch {
            return nil
        }
    }

    func loadImage(fileName: String) -> UIImage? {
        let fileURL = imagesDirectory.appendingPathComponent(fileName)
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return UIImage(data: data)
    }

    func deleteImage(fileName: String) {
        let fileURL = imagesDirectory.appendingPathComponent(fileName)
        try? FileManager.default.removeItem(at: fileURL)
    }

    func migrateFromData(_ data: Data, id: UUID) -> String? {
        let fileName = "\(id.uuidString).jpg"
        let fileURL = imagesDirectory.appendingPathComponent(fileName)
        do {
            try data.write(to: fileURL)
            return fileName
        } catch {
            return nil
        }
    }
}
