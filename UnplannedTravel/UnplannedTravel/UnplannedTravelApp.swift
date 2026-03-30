//
//  UnplannedTravelApp.swift
//  UnplannedTravel
//
//  Created by Ion Jaureguialzo Sarasola on 30/03/2026.
//

import SwiftUI
import SwiftData

@main
struct UnplannedTravelApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([Plan.self, Etapa.self])
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .private("iCloud.com.jaureguialzo.UnplannedTravel")
        )
        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
