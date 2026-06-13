import Foundation

// MARK: - Cat Persistence

/// UserDefaults-based persistence.
final class CatPersistence {

    private let defaults: UserDefaults
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
    }

    // MARK: - Stress Points

    func loadStressPoints() -> Int {
        defaults.integer(forKey: CatPersistenceKeys.stressPoints)
    }

    func saveStressPoints(_ points: Int) {
        defaults.set(points, forKey: CatPersistenceKeys.stressPoints)
    }

    // MARK: - Voucher History

    func loadVoucherHistory() -> [VoucherModel] {
        guard let data = defaults.data(
            forKey: CatPersistenceKeys.voucherHistory
        ) else {
            return []
        }
        return (try? decoder.decode([VoucherModel].self, from: data)) ?? []
    }

    func saveVoucherHistory(_ vouchers: [VoucherModel]) {
        guard let data = try? encoder.encode(vouchers) else { return }
        defaults.set(data, forKey: CatPersistenceKeys.voucherHistory)
    }

    // MARK: - Last Voucher Generated Date (24h cooldown)

    func loadLastVoucherDate() -> Date? {
        defaults.object(forKey: CatPersistenceKeys.lastVoucherGeneratedDate) as? Date
    }

    func saveLastVoucherDate(_ date: Date?) {
        if let date = date {
            defaults.set(date, forKey: CatPersistenceKeys.lastVoucherGeneratedDate)
        } else {
            defaults.removeObject(forKey: CatPersistenceKeys.lastVoucherGeneratedDate)
        }
    }

    // MARK: - Mood History

    func loadMoodHistory() -> [MoodHistoryEntry] {
        guard let data = defaults.data(
            forKey: CatPersistenceKeys.moodHistory
        ) else {
            return []
        }
        return (try? decoder.decode([MoodHistoryEntry].self, from: data)) ?? []
    }

    func saveMoodHistory(_ history: [MoodHistoryEntry]) {
        guard let data = try? encoder.encode(history) else { return }
        defaults.set(data, forKey: CatPersistenceKeys.moodHistory)
    }

    // MARK: - Session State

    func loadLastSessionDate() -> Date? {
        defaults.object(forKey: CatPersistenceKeys.lastSessionDate) as? Date
    }

    func saveLastSessionDate(_ date: Date) {
        defaults.set(date, forKey: CatPersistenceKeys.lastSessionDate)
    }

    // MARK: - Reset All

    func resetAll() {
        let keys = [
            CatPersistenceKeys.stressPoints,
            CatPersistenceKeys.voucherHistory,
            CatPersistenceKeys.moodHistory,
            CatPersistenceKeys.lastSessionDate,
            CatPersistenceKeys.lastVoucherGeneratedDate
        ]
        keys.forEach { defaults.removeObject(forKey: $0) }
    }
}
