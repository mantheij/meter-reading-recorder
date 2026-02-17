import SwiftUI
import CoreData
import FirebaseCore
import FirebaseFirestore
import FirebaseAppCheck
import GoogleSignIn

@main
struct MeterAppApp: App {
    let persistenceController = PersistenceController.shared
    @AppStorage("appAppearance") private var appearanceRaw: String = AppAppearance.system.rawValue
    @AppStorage("appLanguage") private var languageRaw: String = AppLanguage.de.rawValue

    init() {
        #if DEBUG
        let providerFactory = AppCheckDebugProviderFactory()
        #else
        let providerFactory = AppAttestProviderFactory()
        #endif
        AppCheck.setAppCheckProviderFactory(providerFactory)

        FirebaseApp.configure()
        if let clientID = FirebaseApp.app()?.options.clientID {
            GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)
        }

        let firestoreSettings = Firestore.firestore().settings
        firestoreSettings.cacheSettings = PersistentCacheSettings()
        Firestore.firestore().settings = firestoreSettings
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .environment(\.appLanguage, languageRaw)
                .environmentObject(AuthService.shared)
                .environmentObject(SyncService.shared)
                .environmentObject(NetworkMonitor.shared)
                .preferredColorScheme(
                    (AppAppearance(rawValue: appearanceRaw) ?? .system).colorScheme
                )
                .onOpenURL { url in
                    GIDSignIn.sharedInstance.handle(url)
                }
        }
    }
}
