//
//  ContentView.swift
//  HIIT
//
//  Created by Jemin Shin on 4/17/25.
//

import Combine
import AVFoundation
import SwiftData
import SwiftUI

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var timers: [HIITTimer]
    @State private var isAddingTimer = false
    @State private var playingTimer: HIITTimer?
    @State private var deleteError: String?

    var body: some View {
        NavigationSplitView {
            List {
                ForEach(timers) { timer in
                    HStack {
                        Button {
                            playingTimer = timer
                        } label: {
                            Image(systemName: "play.circle.fill")
                                .font(.title2)
                        }
                        .buttonStyle(.borderless)
                        .accessibilityLabel("Play \(timer.name)")

                        NavigationLink {
                            TimerDetailView(timer: timer)
                        } label: {
                            VStack(alignment: .leading) {
                                Text(timer.name)
                                Text("\(formatDuration(seconds(fromMinutes: timer.workPeriod))) work / \(formatDuration(seconds(fromMinutes: timer.restPeriod))) rest / \(timer.rounds) rounds")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
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
        .sheet(item: $playingTimer) { timer in
            NavigationStack {
                LiveTimerView(timer: timer, autoStart: true)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Done") { playingTimer = nil }
                        }
                    }
                    .alert("Couldn't Delete Timer", isPresented: Binding(
                        get: { deleteError != nil },
                        set: { if !$0 { deleteError = nil } }
                    )) {
                        Button("OK", role: .cancel) { deleteError = nil }
                    } message: {
                        Text(deleteError ?? "")
                    }
            }
        }
    }

    private func deleteTimers(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(timers[index])
            }
            do {
                try modelContext.save()
            } catch {
                modelContext.rollback()
                deleteError = error.localizedDescription
            }
        }
    }
}

private struct AddTimerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    private let timer: HIITTimer?
    private let onFinish: (() -> Void)?
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
    @State private var countdownSoundEnabled = true
    @State private var errorMessage: String?

    init(timer: HIITTimer? = nil, onFinish: (() -> Void)? = nil) {
        self.timer = timer
        self.onFinish = onFinish
        if let timer {
            let warmUp = seconds(fromMinutes: timer.warmUp)
            let work = seconds(fromMinutes: timer.workPeriod)
            let rest = seconds(fromMinutes: timer.restPeriod)
            let coolDown = seconds(fromMinutes: timer.coolDown)
            _name = State(initialValue: timer.name)
            _warmUpMinutes = State(initialValue: "\(warmUp / 60)")
            _warmUpSeconds = State(initialValue: "\(warmUp % 60)")
            _workMinutes = State(initialValue: "\(work / 60)")
            _workSeconds = State(initialValue: "\(work % 60)")
            _restMinutes = State(initialValue: "\(rest / 60)")
            _restSeconds = State(initialValue: "\(rest % 60)")
            _coolDownMinutes = State(initialValue: "\(coolDown / 60)")
            _coolDownSeconds = State(initialValue: "\(coolDown % 60)")
            _rounds = State(initialValue: "\(timer.rounds)")
            _countdownSoundEnabled = State(initialValue: timer.countdownSoundEnabled)
        }
    }

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
        guard let value = Int(rounds), (1...maximumRounds).contains(value) else {
            return nil
        }
        return value
    }

    private var maximumRounds: Int { countdownSoundEnabled ? 15 : 30 }

    var body: some View {
        if timer == nil {
            NavigationStack {
                form
            }
        } else {
            form
        }
    }

    private var form: some View {
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
                Text("Seconds over 59 are converted automatically. Choose 1 to \(maximumRounds) rounds so background alerts can be scheduled.")
            }

            Section {
                Toggle("Countdown sound", isOn: $countdownSoundEnabled)
                    .accessibilityIdentifier("timer.countdownSound")
            } footer: {
                Text("A clapper sounds at 5 seconds for phases of 30 seconds or longer, or 3 seconds for shorter phases. Phases of 3 seconds or less have no countdown sound.")
            }
        }
        .navigationTitle(timer == nil ? "New Timer" : "Edit Timer")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel", action: finish)
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

    private func finish() {
        if let onFinish {
            onFinish()
        } else {
            dismiss()
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
            errorMessage = "Enter a name, nonnegative durations, and 1 to \(maximumRounds) work rounds."
            return
        }

        let target = timer ?? HIITTimer(name: trimmedName)
        let oldValues = (target.name, target.warmUp, target.coolDown, target.restPeriod, target.workPeriod, target.rounds, target.countdownSoundEnabled)
        target.name = trimmedName
        target.warmUp = Double(durations.warmUp) / 60
        target.coolDown = Double(durations.coolDown) / 60
        target.restPeriod = Double(durations.rest) / 60
        target.workPeriod = Double(durations.work) / 60
        target.rounds = roundsValue
        target.countdownSoundEnabled = countdownSoundEnabled
        if timer == nil {
            modelContext.insert(target)
        }
        do {
            try modelContext.save()
            finish()
        } catch {
            if timer == nil {
                modelContext.delete(target)
            } else {
                (target.name, target.warmUp, target.coolDown, target.restPeriod, target.workPeriod, target.rounds, target.countdownSoundEnabled) = oldValues
            }
            errorMessage = error.localizedDescription
        }
    }
}

private struct TimerDetailView: View {
    let timer: HIITTimer
    @State private var isEditing = false

    var body: some View {
        if isEditing {
            AddTimerView(timer: timer) {
                isEditing = false
            }
        } else {
            Form {
                Section("Durations") {
                    LabeledContent("Warm-up", value: formatDuration(seconds(fromMinutes: timer.warmUp)))
                    LabeledContent("Work", value: formatDuration(seconds(fromMinutes: timer.workPeriod)))
                    LabeledContent("Rest", value: formatDuration(seconds(fromMinutes: timer.restPeriod)))
                    LabeledContent("Cool-down", value: formatDuration(seconds(fromMinutes: timer.coolDown)))
                    LabeledContent("Work rounds", value: "\(timer.rounds)")
                    LabeledContent("Countdown sound", value: timer.countdownSoundEnabled ? "On" : "Off")
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
            .toolbar {
                Button("Edit") { isEditing = true }
            }
        }
    }
}

private struct LiveTimerView: View {
    let timer: HIITTimer
    var autoStart = false

    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var notifications = WorkoutNotifications()
    @State private var phaseIndex = 0
    @State private var remainingSeconds = 0
    @State private var deadline: Date?
    @State private var isRunning = false
    @State private var hasStarted = false
    @State private var isCompleted = false
    @State private var hasAppeared = false
    @State private var countdownPlayed = false
    @State private var effectPlayers: [String: AVAudioPlayer] = [:]

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
        for round in 1...max(min(timer.rounds, 30), 1) {
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

            if !(1...maximumRounds).contains(timer.rounds) {
                Text("Edit this timer to use 1 to \(maximumRounds) work rounds before starting.")
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
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
                .disabled(phases.isEmpty || !(1...maximumRounds).contains(timer.rounds))
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
        .onAppear {
            if !hasAppeared {
                hasAppeared = true
                reset()
                if autoStart, !phases.isEmpty, (1...maximumRounds).contains(timer.rounds) {
                    toggleRunning()
                }
            }
        }
        .onDisappear {
            notifications.cancel()
        }
        .onReceive(ticker) { now in
            if scenePhase == .active {
                advance(to: now, playSound: true)
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                advance(to: Date(), playSound: false)
            }
        }
        .alert("Workout Sound or Alerts Unavailable", isPresented: Binding(
            get: { notifications.errorMessage != nil },
            set: { if !$0 { notifications.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { notifications.errorMessage = nil }
        } message: {
            Text(notifications.errorMessage ?? "")
        }
    }

    private var maximumRounds: Int { timer.countdownSoundEnabled ? 15 : 30 }

    private func toggleRunning() {
        if isRunning {
            let now = Date()
            advance(to: now, playSound: true)
            guard isRunning, let deadline else {
                return
            }
            remainingSeconds = max(0, Int(ceil(deadline.timeIntervalSince(now))))
            self.deadline = nil
            isRunning = false
            notifications.cancel()
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
        if let deadline {
            notifications.schedule(WorkoutAlert.schedule(
                phases: phases,
                currentIndex: phaseIndex,
                deadline: deadline,
                countdownEnabled: timer.countdownSoundEnabled,
                countdownPlayed: countdownPlayed
            ))
        }
    }

    private func advance(to now: Date, playSound: Bool) {
        guard isRunning, var phaseDeadline = deadline else {
            return
        }

        var changedPhase = false
        while now >= phaseDeadline {
            changedPhase = true
            phaseIndex += 1
            countdownPlayed = false
            guard phases.indices.contains(phaseIndex) else {
                isRunning = false
                isCompleted = true
                remainingSeconds = 0
                deadline = nil
                if playSound {
                    playEffect(named: "round-bell")
                }
                return
            }
            phaseDeadline = phaseDeadline.addingTimeInterval(TimeInterval(phases[phaseIndex].duration))
        }

        deadline = phaseDeadline
        remainingSeconds = max(0, Int(ceil(phaseDeadline.timeIntervalSince(now))))
        if playSound && changedPhase {
            playEffect(named: "round-bell")
        }
        if timer.countdownSoundEnabled, !countdownPlayed,
           let countdownSeconds = currentPhase?.countdownSeconds,
           now >= phaseDeadline.addingTimeInterval(-TimeInterval(countdownSeconds)) {
            countdownPlayed = true
            if playSound {
                playEffect(named: "clapper")
            }
        }
    }

    private func playEffect(named name: String) {
        do {
            guard let url = Bundle.main.url(forResource: name, withExtension: "wav") else {
                notifications.errorMessage = "The workout sound file is missing: \(name).wav."
                return
            }
            let player = try AVAudioPlayer(contentsOf: url)
            effectPlayers[name] = player
            if !player.play() {
                notifications.errorMessage = "The workout sound could not be played."
            }
        } catch {
            notifications.errorMessage = "The workout sound could not be played: \(error.localizedDescription)"
        }
    }

    private func reset() {
        notifications.cancel()
        phaseIndex = 0
        remainingSeconds = phases.first?.duration ?? 0
        deadline = nil
        isRunning = false
        hasStarted = false
        isCompleted = false
        countdownPlayed = false
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
