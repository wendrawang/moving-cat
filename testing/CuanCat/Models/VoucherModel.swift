import Foundation

// MARK: - Voucher Model

struct VoucherModel: Codable, Identifiable {

    /// Unique voucher identifier
    let identifier: String

    /// When the voucher was generated
    let createdAt: Date

    /// Voucher code (e.g. "CAT-ABC123")
    let code: String

    /// Type/category of the voucher
    let voucherType: VoucherType

    /// Whether the voucher has been redeemed by the user
    var isRedeemed: Bool

    /// When the voucher was redeemed (nil if not redeemed)
    var redeemedAt: Date?

    /// Expiry: 7 hari dari createdAt
    static let expiryDuration: TimeInterval = 7 * 24 * 60 * 60

    var expiryDate: Date {
        createdAt.addingTimeInterval(VoucherModel.expiryDuration)
    }

    var isExpired: Bool {
        Date() > expiryDate
    }

    /// Status display
    var statusText: String {
        if isRedeemed { return "Redeemed" }
        if isExpired { return "Expired" }
        return "Active"
    }

    var id: String { identifier }

    init(voucherType: VoucherType) {
        self.identifier = UUID().uuidString
        self.createdAt = Date()
        self.code = VoucherModel.generateCode()
        self.voucherType = voucherType
        self.isRedeemed = false
        self.redeemedAt = nil
    }

    /// Generate a random voucher code
    private static func generateCode() -> String {
        let characters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        let randomPart = (0..<6).compactMap { _ in
            characters.randomElement()
        }
        return "CAT-\(String(randomPart))"
    }

    /// Check if a voucher can be generated (1x per 24 hours)
    static func canGenerateVoucher(lastGeneratedDate: Date?) -> Bool {
        guard let lastDate = lastGeneratedDate else { return true }
        let elapsed = Date().timeIntervalSince(lastDate)
        return elapsed >= CatStressConstants.voucherCooldownInterval
    }
}

// MARK: - Voucher Type

enum VoucherType: String, Codable, CaseIterable {
    case apology       // Cat was exhausted / high stress
    case loyalty       // Future: repeated usage reward
    case milestone     // Future: interaction milestones

    var displayTitle: String {
        switch self {
        case .apology:   return "Sorry for the wait!"
        case .loyalty:   return "Loyalty Reward"
        case .milestone: return "Milestone Reached!"
        }
    }

    var displayDescription: String {
        switch self {
        case .apology:
            return "Our cat noticed you waited too long. Here's a treat!"
        case .loyalty:
            return "Thanks for being a loyal user!"
        case .milestone:
            return "You've reached a special milestone!"
        }
    }
}
