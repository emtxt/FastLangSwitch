import Foundation

/// Owns an observer token and removes it when released, on any thread. Keeping
/// cleanup here avoids accessing non-Sendable tokens from an actor's deinit.
final class NotificationObservation {
    private let center: NotificationCenter
    private let token: NSObjectProtocol

    init(center: NotificationCenter, name: Notification.Name,
         handler: @escaping @MainActor @Sendable () -> Void) {
        self.center = center
        token = center.addObserver(forName: name, object: nil, queue: .main) { _ in
            // Foundation delivers this observer on the explicitly chosen main
            // queue. Assert that guarantee without introducing an async hop.
            MainActor.assumeIsolated { handler() }
        }
    }

    deinit { center.removeObserver(token) }
}
