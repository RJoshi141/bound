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
        let schema = Schema([
            Book.self, Note.self, Meetup.self,
            ClubMember.self, LedgerEntry.self, Recommendation.self, PickOption.self,
        ])
        // Own store file, so the old template store (Item) never gets in the way.
        let storeURL = URL.applicationSupportDirectory.appending(path: "Bound.store")
        // Application Support doesn't exist on a fresh install, and SwiftData won't make it for a custom URL.
        try? FileManager.default.createDirectory(at: .applicationSupportDirectory, withIntermediateDirectories: true)
        let configuration = ModelConfiguration(schema: schema, url: storeURL)

        if let container = try? ModelContainer(for: schema, configurations: [configuration]) {
            return container
        }

        // Local-only for now: if the schema changed in a way SwiftData can't migrate,
        // wipe the store and start fresh instead of crashing. Sample data reseeds on launch.
        let fm = FileManager.default
        for suffix in ["", "-shm", "-wal"] {
            try? fm.removeItem(at: URL(filePath: storeURL.path() + suffix))
        }
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
