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
    @NSManaged public var imageData: Data?
}

extension MeterReading : Identifiable {
    
}
