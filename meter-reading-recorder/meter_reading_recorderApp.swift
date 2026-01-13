//
//  meter_reading_recorderApp.swift
//  meter-reading-recorder
//
//  Created by Jan Manthei on 13.01.26.
//

import SwiftUI
import CoreData

@main
struct meter_reading_recorderApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
