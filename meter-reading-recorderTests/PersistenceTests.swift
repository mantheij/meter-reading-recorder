import Testing
import CoreData
@testable import meter_reading_recorder

@Suite(.serialized)
struct PersistenceTests {

    private func makeInMemoryController() -> PersistenceController {
        PersistenceController(inMemory: true)
    }

    @Test func inMemoryContainerCreated() {
        let controller = makeInMemoryController()
        #expect(controller.container.viewContext.persistentStoreCoordinator != nil)
    }

    @Test func createAndSaveMeterReading() throws {
        let controller = makeInMemoryController()
        let ctx = controller.container.viewContext

        let reading = MeterReading(context: ctx)
        reading.id = UUID()
        reading.value = "12345"
        reading.meterType = "water"
        reading.date = Date()

        try ctx.save()

        let request = MeterReading.fetchRequest()
        let results = try ctx.fetch(request)
        #expect(results.count == 1)
    }

    @Test func savedValuesReadBack() throws {
        let controller = makeInMemoryController()
        let ctx = controller.container.viewContext
        let testDate = Date()
        let testId = UUID()

        let reading = MeterReading(context: ctx)
        reading.id = testId
        reading.value = "67890"
        reading.meterType = "electricity"
        reading.date = testDate

        try ctx.save()

        let request = MeterReading.fetchRequest()
        let results = try ctx.fetch(request)
        let fetched = try #require(results.first)

        #expect(fetched.id == testId)
        #expect(fetched.value == "67890")
        #expect(fetched.meterType == "electricity")
        #expect(fetched.date == testDate)
    }

    @Test func fetchWithPredicate() throws {
        let controller = makeInMemoryController()
        let ctx = controller.container.viewContext

        let r1 = MeterReading(context: ctx)
        r1.id = UUID()
        r1.value = "111"
        r1.meterType = "water"
        r1.date = Date()

        let r2 = MeterReading(context: ctx)
        r2.id = UUID()
        r2.value = "222"
        r2.meterType = "gas"
        r2.date = Date()

        try ctx.save()

        let request = MeterReading.fetchRequest()
        request.predicate = NSPredicate(format: "meterType == %@", "water")
        let results = try ctx.fetch(request)
        #expect(results.count == 1)
        #expect(results.first?.value == "111")
    }

    @Test func deleteReading() throws {
        let controller = makeInMemoryController()
        let ctx = controller.container.viewContext

        let reading = MeterReading(context: ctx)
        reading.id = UUID()
        reading.value = "999"
        reading.meterType = "gas"
        reading.date = Date()

        try ctx.save()

        ctx.delete(reading)
        try ctx.save()

        let request = MeterReading.fetchRequest()
        let results = try ctx.fetch(request)
        #expect(results.isEmpty)
    }

    @Test func imageDataIsOptional() throws {
        let controller = makeInMemoryController()
        let ctx = controller.container.viewContext

        let reading = MeterReading(context: ctx)
        reading.id = UUID()
        reading.value = "555"
        reading.meterType = "water"
        reading.date = Date()
        reading.imageData = nil

        try ctx.save()

        let request = MeterReading.fetchRequest()
        let results = try ctx.fetch(request)
        #expect(results.first?.imageData == nil)
    }
}
