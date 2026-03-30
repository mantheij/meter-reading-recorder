import Foundation

actor RateLimiter {
    private let maxAttempts: Int
    private let windowSeconds: TimeInterval
    private var attempts: [Date] = []

    init(maxAttempts: Int = 5, windowSeconds: TimeInterval = 300) {
        self.maxAttempts = maxAttempts
        self.windowSeconds = windowSeconds
    }

    func canAttempt() -> Bool {
        pruneExpired()
        return attempts.count < maxAttempts
    }

    func recordAttempt() {
        pruneExpired()
        attempts.append(Date())
    }

    func reset() {
        attempts.removeAll()
    }

    var remainingLockoutSeconds: TimeInterval {
        pruneExpired()
        guard attempts.count >= maxAttempts, let oldest = attempts.first else { return 0 }
        let unlockTime = oldest.addingTimeInterval(windowSeconds)
        return max(0, unlockTime.timeIntervalSince(Date()))
    }

    private func pruneExpired() {
        let cutoff = Date().addingTimeInterval(-windowSeconds)
        attempts.removeAll { $0 < cutoff }
    }
}
