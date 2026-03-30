//
//  ContentView.swift
//  UnplannedTravel
//
//  Created by Ion Jaureguialzo Sarasola on 30/03/2026.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        PlanesView()
    }
}

#Preview {
    ContentView()
        .environment(CloudKitStore())
}
