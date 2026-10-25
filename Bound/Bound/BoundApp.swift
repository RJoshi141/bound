//
//  BoundApp.swift
//  Bound
//
//  Created by Ritika Joshi on 10/24/26.
//

import SwiftUI
import SwiftData

@main
struct BoundApp: App {
    init() {
        FontRegistrar.registerAll()
    }

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([Book.self, Note.self, Meetup.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [configuration])
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
