import Foundation

struct ConflictData: Codable {
    let value: String
    let date: Date
    let updatedAt: Date
    let deviceId: String
    let version: Int64
    let imagePath: String?
}
