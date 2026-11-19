//
//  HIITTests.swift
//  HIITTests
//
//  Created by Jemin Shin on 4/17/25.
//

import Testing
import Foundation
import SwiftData
@testable import HIIT

private enum PreviousSchema {
    @Model
    final class HIITTimer {
        var name: String
        var warmUp: Double
        var coolDown: Double
        var restPeriod: Double
        var workPeriod: Double

        init(name: String, workPeriod: Double) {
            self.name = name
            self.warmUp = 0.5
            self.coolDown = 0.5
            self.restPeriod = 0.5
            self.workPeriod = workPeriod
        }
    }
}

struct HIITTests {

    @Test func example() async throws {
        // Write your test here and use APIs like `#expect(...)` to check expected conditions.
    }

    @Test @MainActor func existingTimersMigrateWithDefaultRounds() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("HIIT-migration-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let storeURL = directory.appendingPathComponent("default.store")

        do {
            let schema = Schema([Item.self, PreviousSchema.HIITTimer.self])
            let configuration = ModelConfiguration(schema: schema, url: storeURL)
            let container = try ModelContainer(for: schema, configurations: [configuration])
            let context = ModelContext(container)
            context.insert(PreviousSchema.HIITTimer(name: "Existing workout", workPeriod: 1.5))
            try context.save()
        }

        let schema = Schema([Item.self, HIITTimer.self])
        let configuration = ModelConfiguration(schema: schema, url: storeURL)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = ModelContext(container)
        let timers = try context.fetch(FetchDescriptor<HIITTimer>())
        #expect(timers.count == 1)
        let timer = try #require(timers.first)
        #expect(timer.name == "Existing workout")
        #expect(timer.workPeriod == 1.5)
        #expect(timer.rounds == 8)
    }

}
