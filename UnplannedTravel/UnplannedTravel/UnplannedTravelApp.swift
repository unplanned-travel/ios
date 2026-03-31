//
//  UnplannedTravelApp.swift
//  UnplannedTravel
//
//  Created by Ion Jaureguialzo Sarasola on 30/03/2026.
//

import SwiftUI

@main
struct UnplannedTravelApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var store = CloudKitStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(store)
        }
        .handlesExternalEvents(matching: ["*"])
    }
}
