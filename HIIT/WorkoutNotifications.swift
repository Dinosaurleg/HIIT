import Combine
import Foundation
import UserNotifications

struct WorkoutPhase {
    let title: String
    let duration: Int
    let round: Int?

    var countdownSeconds: Int? {
        guard duration > 3 else { return nil }
        return duration >= 30 ? 5 : 3
    }
}

struct WorkoutAlert {
    enum Sound: Equatable {
        case countdown
        case bell
    }

    let date: Date
    let title: String
    let sound: Sound

    static func schedule(
        phases: [WorkoutPhase],
        currentIndex: Int,
        deadline: Date,
        countdownEnabled: Bool,
        countdownPlayed: Bool
    ) -> [WorkoutAlert] {
        var alerts: [WorkoutAlert] = []
        var nextDate = deadline
        for index in currentIndex..<phases.count {
            let phase = phases[index]
            if index > currentIndex {
                nextDate = nextDate.addingTimeInterval(TimeInterval(phase.duration))
            }
            if countdownEnabled, let seconds = phase.countdownSeconds,
               !(index == currentIndex && countdownPlayed) {
                alerts.append(WorkoutAlert(
                    date: nextDate.addingTimeInterval(-TimeInterval(seconds)),
                    title: "\(phase.title): \(seconds) seconds remaining",
                    sound: .countdown
                ))
            }
            let nextTitle = index + 1 < phases.count ? phases[index + 1].title : "Workout Complete"
            alerts.append(WorkoutAlert(date: nextDate, title: nextTitle, sound: .bell))
        }
        return alerts
    }
}

@MainActor
final class WorkoutNotifications: ObservableObject {
    @Published var errorMessage: String?

    private let center = UNUserNotificationCenter.current()
    private var generation = UUID()
    private var identifiers: [String] = []

    func cancel() {
        generation = UUID()
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
        identifiers = []
    }

    func schedule(_ alerts: [WorkoutAlert]) {
        cancel()
        let currentGeneration = generation

        Task {
            do {
                let settings = await center.notificationSettings()
                let authorized: Bool
                switch settings.authorizationStatus {
                case .notDetermined:
                    authorized = try await center.requestAuthorization(options: [.alert, .sound])
                case .authorized, .provisional, .ephemeral:
                    authorized = true
                default:
                    authorized = false
                }
                guard generation == currentGeneration else { return }
                guard authorized else {
                    errorMessage = "Enable notifications in Settings to hear workout alerts when the app is in the background."
                    return
                }

                for alert in alerts {
                    guard generation == currentGeneration else { return }
                    let delay = alert.date.timeIntervalSinceNow
                    guard delay > 0 else { continue }

                    let identifier = "workout-\(currentGeneration.uuidString)-\(identifiers.count)"
                    identifiers.append(identifier)
                    let content = UNMutableNotificationContent()
                    content.title = alert.title
                    switch alert.sound {
                    case .countdown:
                        content.sound = UNNotificationSound(named: UNNotificationSoundName("clapper.wav"))
                    case .bell:
                        content.sound = UNNotificationSound(named: UNNotificationSoundName("round-bell.wav"))
                    }
                    let trigger = UNTimeIntervalNotificationTrigger(timeInterval: delay, repeats: false)
                    let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
                    try await center.add(request)
                    if generation != currentGeneration {
                        center.removePendingNotificationRequests(withIdentifiers: [identifier])
                        return
                    }
                }
            } catch {
                guard generation == currentGeneration else { return }
                cancel()
                errorMessage = "Background workout alerts could not be scheduled: \(error.localizedDescription)"
            }
        }
    }
}
