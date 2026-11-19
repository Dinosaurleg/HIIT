import Combine
import Foundation
import UserNotifications

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

    func schedule(_ alerts: [(date: Date, title: String)]) {
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
                    content.sound = .default
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
