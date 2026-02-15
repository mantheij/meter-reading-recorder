import Foundation
import CoreData

extension MeterReading {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<MeterReading> {
        return NSFetchRequest<MeterReading>(entityName: "MeterReading")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var value: String?
    @NSManaged public var meterType: String?
    @NSManaged public var date: Date?
    @NSManaged public var createdAt: Date?
    @NSManaged public var modifiedAt: Date?
    @NSManaged public var softDeleted: Bool
    @NSManaged public var deletedAt: Date?
    @NSManaged public var imageFileName: String?
    @NSManaged public var userId: String?

    // Deprecated: kept for v1→v2 migration only. Will be removed in a future model version.
    @NSManaged public var imageData: Data?

    /// Builds a predicate scoped to the given user, optionally filtered by meter type.
    static func scopedPredicate(meterType: String? = nil, userId: String?) -> NSPredicate {
        var subpredicates: [NSPredicate] = [
            NSPredicate(format: "softDeleted == NO")
        ]

        if let userId = userId {
            subpredicates.append(NSPredicate(format: "userId == %@", userId))
        } else {
            subpredicates.append(NSPredicate(format: "userId == nil"))
        }

        if let meterType = meterType {
            subpredicates.append(NSPredicate(format: "meterType == %@", meterType))
        }

        return NSCompoundPredicate(andPredicateWithSubpredicates: subpredicates)
    }
}

extension MeterReading : Identifiable {

}
