//
//  ContentView.swift
//  UnplannedTravel
//
//  Created by Ion Jaureguialzo Sarasola on 30/03/2026.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    var body: some View {
        PlanesView()
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Plan.self, Etapa.self], inMemory: true)
}
