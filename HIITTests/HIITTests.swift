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

private enum PreviousRoundsSchema {
    @Model
    final class HIITTimer {
        var name: String
        var warmUp: Double
        var coolDown: Double
        var restPeriod: Double
        var workPeriod: Double
        var rounds: Int = 8

        init(name: String, rounds: Int) {
            self.name = name
            self.warmUp = 0.5
            self.coolDown = 0.5
            self.restPeriod = 0.5
            self.workPeriod = 1.5
            self.rounds = rounds
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
        #expect(timer.countdownSoundEnabled)
    }

    @Test @MainActor func existingRoundCountsSurviveCountdownSoundMigration() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("HIIT-migration-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let storeURL = directory.appendingPathComponent("default.store")

        do {
            let schema = Schema([Item.self, PreviousRoundsSchema.HIITTimer.self])
            let container = try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, url: storeURL)])
            let context = ModelContext(container)
            context.insert(PreviousRoundsSchema.HIITTimer(name: "Saved workout", rounds: 12))
            try context.save()
        }

        let schema = Schema([Item.self, HIITTimer.self])
        let container = try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, url: storeURL)])
        let timer = try #require(ModelContext(container).fetch(FetchDescriptor<HIITTimer>()).first)
        #expect(timer.name == "Saved workout")
        #expect(timer.rounds == 12)
        #expect(timer.countdownSoundEnabled)
    }

    @Test func countdownThresholdsRespectPhaseDuration() {
        for (duration, expected) in [(0, nil), (3, nil), (4, 3), (29, 3), (30, 5), (31, 5)] as [(Int, Int?)] {
            let phase = WorkoutPhase(title: "Work", duration: duration, round: 1)
            #expect(phase.countdownSeconds == expected)
        }
    }

    @Test func alertsUseBellForEveryPhaseAndClapperAtThreshold() {
        let phases = [
            WorkoutPhase(title: "Warm-up", duration: 30, round: nil),
            WorkoutPhase(title: "Work", duration: 4, round: 1),
            WorkoutPhase(title: "Rest", duration: 3, round: 1),
            WorkoutPhase(title: "Cool-down", duration: 29, round: nil)
        ]
        let deadline = Date(timeIntervalSince1970: 100)
        let alerts = WorkoutAlert.schedule(
            phases: phases,
            currentIndex: 0,
            deadline: deadline,
            countdownEnabled: true,
            countdownPlayed: false
        )

        #expect(alerts.map(\.date) == [95, 100, 101, 104, 107, 133, 136].map { Date(timeIntervalSince1970: $0) })
        #expect(alerts.map(\.sound) == [.countdown, .bell, .countdown, .bell, .bell, .countdown, .bell])
        #expect(alerts.map(\.title) == [
            "Warm-up: 5 seconds remaining", "Work",
            "Work: 3 seconds remaining", "Rest", "Cool-down",
            "Cool-down: 3 seconds remaining", "Workout Complete"
        ])
    }

    @Test func resumedAndDisabledCountdownsDoNotRepeatClapper() {
        let phases = [
            WorkoutPhase(title: "Work", duration: 30, round: 1),
            WorkoutPhase(title: "Rest", duration: 29, round: 1)
        ]
        let deadline = Date(timeIntervalSince1970: 100)
        let resumed = WorkoutAlert.schedule(
            phases: phases, currentIndex: 0, deadline: deadline,
            countdownEnabled: true, countdownPlayed: true
        )
        #expect(resumed.map(\.date) == [100, 126, 129].map { Date(timeIntervalSince1970: $0) })
        #expect(resumed.map(\.sound) == [.bell, .countdown, .bell])

        let disabled = WorkoutAlert.schedule(
            phases: phases, currentIndex: 0, deadline: deadline,
            countdownEnabled: false, countdownPlayed: false
        )
        #expect(disabled.map(\.sound) == [.bell, .bell])

        let laterPhase = WorkoutAlert.schedule(
            phases: phases, currentIndex: 1, deadline: deadline,
            countdownEnabled: true, countdownPlayed: false
        )
        #expect(laterPhase.map(\.date) == [97, 100].map { Date(timeIntervalSince1970: $0) })
        #expect(laterPhase.last?.title == "Workout Complete")
    }

    @Test func maximumRoundSchedulesFitNotificationLimit() {
        for (rounds, countdownEnabled) in [(15, true), (30, false)] {
            var phases = [WorkoutPhase(title: "Warm-up", duration: 30, round: nil)]
            for round in 1...rounds {
                phases.append(WorkoutPhase(title: "Work", duration: 30, round: round))
                if round < rounds {
                    phases.append(WorkoutPhase(title: "Rest", duration: 30, round: round))
                }
            }
            phases.append(WorkoutPhase(title: "Cool-down", duration: 30, round: nil))
            let alerts = WorkoutAlert.schedule(
                phases: phases, currentIndex: 0, deadline: Date(timeIntervalSince1970: 100),
                countdownEnabled: countdownEnabled, countdownPlayed: false
            )
            #expect(alerts.count == (countdownEnabled ? 62 : 61))
            #expect(alerts.count <= 64)
        }
    }

}
