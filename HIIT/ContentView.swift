//
//  ContentView.swift
//  HIIT
//
//  Created by Jemin Shin on 4/17/25.
//

import Combine
import SwiftData
import SwiftUI

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var timers: [HIITTimer]
    @State private var isAddingTimer = false

    var body: some View {
        NavigationSplitView {
            List {
                ForEach(timers) { timer in
                    NavigationLink {
                        TimerDetailView(timer: timer)
                    } label: {
                        VStack(alignment: .leading) {
                            Text(timer.name)
                            Text("\(formatDuration(seconds(fromMinutes: timer.workPeriod))) work / \(formatDuration(seconds(fromMinutes: timer.restPeriod))) rest")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .onDelete(perform: deleteTimers)
            }
            .navigationTitle("Timers")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    EditButton()
                }
                ToolbarItem {
                    Button {
                        isAddingTimer = true
                    } label: {
                        Label("Add Timer", systemImage: "plus")
                    }
                }
            }
        } detail: {
            Text("Select a timer")
        }
        .sheet(isPresented: $isAddingTimer) {
            AddTimerView()
        }
    }

    private func deleteTimers(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(timers[index])
            }
        }
    }
}

private struct AddTimerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var name = ""
    @State private var warmUpMinutes = "0"
    @State private var warmUpSeconds = "30"
    @State private var workMinutes = "0"
    @State private var workSeconds = "30"
    @State private var restMinutes = "0"
    @State private var restSeconds = "30"
    @State private var coolDownMinutes = "0"
    @State private var coolDownSeconds = "30"
    @State private var rounds = "8"
    @State private var errorMessage: String?

    private var durations: (warmUp: Int, work: Int, rest: Int, coolDown: Int)? {
        guard let warmUp = duration(minutes: warmUpMinutes, seconds: warmUpSeconds),
              let work = duration(minutes: workMinutes, seconds: workSeconds),
              let rest = duration(minutes: restMinutes, seconds: restSeconds),
              let coolDown = duration(minutes: coolDownMinutes, seconds: coolDownSeconds) else {
            return nil
        }
        return (warmUp, work, rest, coolDown)
    }

    private var roundsValue: Int? {
        guard let value = Int(rounds), value > 0 else {
            return nil
        }
        return value
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Timer") {
                    TextField("Timer name", text: $name)
                        .textInputAutocapitalization(.words)
                        .accessibilityIdentifier("timer.name")
                }

                Section {
                    durationField("Warm-up", minutes: $warmUpMinutes, seconds: $warmUpSeconds, identifier: "timer.warmUp")
                    durationField("Work", minutes: $workMinutes, seconds: $workSeconds, identifier: "timer.workPeriod")
                    durationField("Rest", minutes: $restMinutes, seconds: $restSeconds, identifier: "timer.restPeriod")
                    durationField("Cool-down", minutes: $coolDownMinutes, seconds: $coolDownSeconds, identifier: "timer.coolDown")
                    HStack {
                        Text("Work rounds")
                        Spacer()
                        TextField("Rounds", text: $rounds)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .accessibilityIdentifier("timer.rounds")
                    }
                } header: {
                    Text("Durations")
                } footer: {
                    Text("Each duration starts at 0 minutes, 30 seconds. Seconds over 59 are converted automatically.")
                }
            }
            .navigationTitle("New Timer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: saveTimer)
                        .disabled(
                            name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                            durations == nil ||
                            roundsValue == nil
                        )
                        .accessibilityIdentifier("timer.save")
                }
            }
            .alert("Couldn't Save Timer", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    private func durationField(
        _ title: String,
        minutes: Binding<String>,
        seconds: Binding<String>,
        identifier: String
    ) -> some View {
        HStack(spacing: 8) {
            Text(title)
            Spacer(minLength: 4)
            TextField("min", text: minutes)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 44)
                .accessibilityLabel("\(title) minutes")
                .accessibilityIdentifier("\(identifier).minutes")
            Text("min")
                .foregroundStyle(.secondary)
            TextField("sec", text: seconds)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 44)
                .accessibilityLabel("\(title) seconds")
                .accessibilityIdentifier("\(identifier).seconds")
            Text("sec")
                .foregroundStyle(.secondary)
        }
    }

    private func duration(minutes: String, seconds: String) -> Int? {
        guard let minuteValue = nonnegativeInteger(minutes),
              let secondValue = nonnegativeInteger(seconds) else {
            return nil
        }

        let (minuteSeconds, multiplicationOverflow) = minuteValue.multipliedReportingOverflow(by: 60)
        let (totalSeconds, additionOverflow) = minuteSeconds.addingReportingOverflow(secondValue)
        guard !multiplicationOverflow, !additionOverflow else {
            return nil
        }
        return totalSeconds
    }

    private func nonnegativeInteger(_ text: String) -> Int? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return 0
        }
        guard let value = Int(trimmed), value >= 0 else {
            return nil
        }
        return value
    }

    private func saveTimer() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty, let durations, let roundsValue else {
            errorMessage = "Enter a name, nonnegative durations, and at least one work round."
            return
        }

        let timer = HIITTimer(
            name: trimmedName,
            warmUp: Double(durations.warmUp) / 60,
            coolDown: Double(durations.coolDown) / 60,
            restPeriod: Double(durations.rest) / 60,
            workPeriod: Double(durations.work) / 60,
            rounds: roundsValue
        )
        modelContext.insert(timer)
        do {
            try modelContext.save()
            dismiss()
        } catch {
            modelContext.delete(timer)
            errorMessage = error.localizedDescription
        }
    }
}

private struct TimerDetailView: View {
    let timer: HIITTimer

    var body: some View {
        Form {
            Section("Durations") {
                LabeledContent("Warm-up", value: formatDuration(seconds(fromMinutes: timer.warmUp)))
                LabeledContent("Work", value: formatDuration(seconds(fromMinutes: timer.workPeriod)))
                LabeledContent("Rest", value: formatDuration(seconds(fromMinutes: timer.restPeriod)))
                LabeledContent("Cool-down", value: formatDuration(seconds(fromMinutes: timer.coolDown)))
                LabeledContent("Work rounds", value: "\(timer.rounds)")
            }
            Section {
                NavigationLink {
                    LiveTimerView(timer: timer)
                } label: {
                    Label("Start Workout", systemImage: "play.fill")
                }
                .accessibilityIdentifier("timer.startWorkout")
            }
        }
        .navigationTitle(timer.name)
    }
}

private struct WorkoutPhase {
    let title: String
    let duration: Int
    let round: Int?
}

private struct LiveTimerView: View {
    let timer: HIITTimer

    @State private var phaseIndex = 0
    @State private var remainingSeconds = 0
    @State private var deadline: Date?
    @State private var isRunning = false
    @State private var hasStarted = false
    @State private var isCompleted = false

    private let ticker = Timer.publish(every: 0.25, on: .main, in: .common).autoconnect()

    private var phases: [WorkoutPhase] {
        var result: [WorkoutPhase] = []
        let warmUp = seconds(fromMinutes: timer.warmUp)
        let work = seconds(fromMinutes: timer.workPeriod)
        let rest = seconds(fromMinutes: timer.restPeriod)
        let coolDown = seconds(fromMinutes: timer.coolDown)

        if warmUp > 0 {
            result.append(WorkoutPhase(title: "Warm-up", duration: warmUp, round: nil))
        }
        for round in 1...max(timer.rounds, 1) {
            if work > 0 {
                result.append(WorkoutPhase(title: "Work", duration: work, round: round))
            }
            if rest > 0, round < timer.rounds {
                result.append(WorkoutPhase(title: "Rest", duration: rest, round: round))
            }
        }
        if coolDown > 0 {
            result.append(WorkoutPhase(title: "Cool-down", duration: coolDown, round: nil))
        }
        return result
    }

    private var currentPhase: WorkoutPhase? {
        guard phases.indices.contains(phaseIndex) else {
            return nil
        }
        return phases[phaseIndex]
    }

    var body: some View {
        VStack(spacing: 24) {
            if isCompleted {
                Text("Workout Complete")
                    .font(.title2.weight(.semibold))
            } else if let currentPhase {
                Text(currentPhase.title)
                    .font(.title2.weight(.semibold))
                    .accessibilityIdentifier("timer.phase")

                if let round = currentPhase.round {
                    Text("Round \(round) of \(timer.rounds)")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("No timed phases")
                    .font(.title2.weight(.semibold))
            }

            Text(formatClock(remainingSeconds))
                .font(.system(size: 72, weight: .bold, design: .rounded).monospacedDigit())
                .contentTransition(.numericText())
                .accessibilityIdentifier("timer.countdown")

            HStack(spacing: 20) {
                Button(action: toggleRunning) {
                    Label(
                        isRunning ? "Pause" : isCompleted ? "Start Again" : hasStarted ? "Resume" : "Start",
                        systemImage: isRunning ? "pause.fill" : "play.fill"
                    )
                    .frame(minWidth: 120)
                }
                .buttonStyle(.borderedProminent)
                .disabled(phases.isEmpty)
                .accessibilityIdentifier("timer.startPause")

                Button(action: reset) {
                    Label("Reset", systemImage: "arrow.counterclockwise")
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("timer.reset")
            }
        }
        .padding()
        .navigationTitle(timer.name)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: reset)
        .onReceive(ticker) { now in
            advance(to: now)
        }
    }

    private func toggleRunning() {
        if isRunning {
            let now = Date()
            advance(to: now)
            guard isRunning, let deadline else {
                return
            }
            remainingSeconds = max(0, Int(ceil(deadline.timeIntervalSince(now))))
            self.deadline = nil
            isRunning = false
            return
        }

        if isCompleted {
            reset()
        }
        guard let currentPhase else {
            isCompleted = true
            return
        }

        hasStarted = true
        isCompleted = false
        deadline = Date().addingTimeInterval(TimeInterval(remainingSeconds == 0 ? currentPhase.duration : remainingSeconds))
        isRunning = true
    }

    private func advance(to now: Date) {
        guard isRunning, var phaseDeadline = deadline else {
            return
        }

        while now >= phaseDeadline {
            phaseIndex += 1
            guard phases.indices.contains(phaseIndex) else {
                isRunning = false
                isCompleted = true
                remainingSeconds = 0
                deadline = nil
                return
            }
            phaseDeadline = phaseDeadline.addingTimeInterval(TimeInterval(phases[phaseIndex].duration))
        }

        deadline = phaseDeadline
        remainingSeconds = max(0, Int(ceil(phaseDeadline.timeIntervalSince(now))))
    }

    private func reset() {
        phaseIndex = 0
        remainingSeconds = phases.first?.duration ?? 0
        deadline = nil
        isRunning = false
        hasStarted = false
        isCompleted = false
    }
}

private func seconds(fromMinutes minutes: Double) -> Int {
    guard minutes.isFinite, minutes > 0 else {
        return 0
    }
    return Int((minutes * 60).rounded())
}

private func formatDuration(_ seconds: Int) -> String {
    "\(seconds / 60):\(String(format: "%02d", seconds % 60))"
}

private func formatClock(_ seconds: Int) -> String {
    String(format: "%02d:%02d", seconds / 60, seconds % 60)
}

#Preview {
    ContentView()
        .modelContainer(for: [HIITTimer.self, Item.self], inMemory: true)
}
