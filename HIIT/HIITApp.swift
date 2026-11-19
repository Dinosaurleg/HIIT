//
//  HIITApp.swift
//  HIIT
//
//  Created by Jemin Shin on 4/17/25.
//

import SwiftUI
import SwiftData

@main
struct HIITApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Item.self,
            HIITTimer.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

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
