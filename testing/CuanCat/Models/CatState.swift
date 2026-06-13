import CoreGraphics
import Foundation

// MARK: - Cat State

enum CatState: String, CaseIterable, Codable {
    case idle
    case walking
    case annoyed       // transaksi gagal (variant 1)
    case sad           // transaksi gagal (variant 2 — random 50/50 dengan annoyed)
    case happy         // transaksi berhasil
    case exhausted     // loading > 10 detik

    /// State yang auto-return ke idle setelah durasi
    var isTransientReaction: Bool {
        switch self {
        case .annoyed, .sad, .happy, .exhausted:
            return true
        default:
            return false
        }
    }

    // MARK: - USDC Animation Mapping

    var animationType: CatAnimationType {
        switch self {
        case .idle:      return .idle
        case .walking:   return .walk
        case .annoyed:   return .annoyed
        case .sad:       return .sad
        case .happy:     return .happy
        case .exhausted: return .exhausted
        }
    }
    
    var forceButtonName: String {
        switch self {
        case .idle:      return "Idle"
        case .walking:   return ""
        case .annoyed:   return "Simulasi Transaction Gagal (1)"
        case .sad:       return "Simulasi Transaction Gagal (2)"
        case .happy:     return "Simulasi Transaction Berhasil"
        case .exhausted: return "Simulasi Loading Lebih dari 10s"
        }
    }

    /// Semua animasi loop
    var usdcAnimationLoops: Bool { true }
}

// MARK: - Walking Direction

enum CatDirection: String, Codable {
    case left
    case right

    var flipped: CatDirection {
        self == .left ? .right : .left
    }

    var scaleX: CGFloat {
        self == .left ? -1.0 : 1.0
    }
}

// MARK: - Cat Loading Type

/// Menentukan apakah loading ini bisa memunculkan animasi exhausted.
///
/// - tracked: full behavior — patience decay + exhausted animation jika >10s.
///   Pakai untuk API utama yang blocking (transaksi, submit, dll).
///
/// - silent: patience decay + stress conversion saja, TIDAK ada exhausted animation.
///   Pakai untuk background/inquiry API yang tidak perlu ditampilkan ke user.
enum CatLoadingType {
    case tracked   // full: patience + exhausted animation
    case silent    // patience + stress saja, no exhausted
}

// MARK: - Cat Event

enum CatEvent {
    // Idle progression
    case idleTimerTick(TimeInterval)

    // Loading lifecycle
    case loadingStarted
    case loadingTimerTick(TimeInterval)
    case loadingStopped

    // Transaction result
    case transactionSuccess
    case transactionFailed       // → annoyed
    case transactionFailedSad    // → sad (random 50/50 dengan transactionFailed)

    // Animation done
    case animationFinished

    // System
    case dayChanged
    case voucherClaimed
}

// MARK: - Side Effect

enum CatSideEffect {
    // Idle timer
    case resetIdleTimer
    case startIdleTimer
    case stopIdleTimer

    // Loading timer
    case startLoadingTimer
    case stopLoadingTimer

    // Stress
    case applyStressDelta(Int)
    case checkVoucherThreshold
    case checkVoucherEarlyThreshold   // gateway timeout: threshold lebih rendah (75)

    // Patience
    case applyPatienceStress           // konversi patience saat ini → stress delta

    // Session tracking
    case incrementExhaustedCount      // +1 saat masuk exhausted state
    case resetExhaustedCount          // reset saat ganti hari

    // Walk
    case updateWalkDirection
    case setHomeBase

    // Logging
    case logStateHistory(CatState)

    // Haptic
    case playHapticFeedback(HapticStyle)

    // Sound
    case playSound(CatSoundType)

    // Animation scheduling
    case scheduleAnimationEnd(TimeInterval)
}

// MARK: - Haptic Style

enum HapticStyle {
    case light
    case medium
    case success
    case warning
}

// MARK: - Transition Result

struct CatTransitionResult {
    let newState: CatState
    let sideEffects: [CatSideEffect]
}
