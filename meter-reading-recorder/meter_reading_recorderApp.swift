import SwiftUI
import CoreData

@main
struct MeterAppApp: App {
    let persistenceController = PersistenceController.shared
    @AppStorage("appAppearance") private var appearanceRaw: String = AppAppearance.system.rawValue

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .preferredColorScheme(
                    (AppAppearance(rawValue: appearanceRaw) ?? .system).colorScheme
                )
        }
    }
}
