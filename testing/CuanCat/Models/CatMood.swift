import Foundation

// MARK: - State History Entry

/// Log setiap state change beserta snapshot stress saat itu.
struct MoodHistoryEntry: Codable, Identifiable {
    let identifier: String
    let timestamp: Date
    let state: CatState
    let stressSnapshot: Int

    var id: String { identifier }

    init(state: CatState, stress: Int) {
        self.identifier = UUID().uuidString
        self.timestamp = Date()
        self.state = state
        self.stressSnapshot = stress
    }
}
