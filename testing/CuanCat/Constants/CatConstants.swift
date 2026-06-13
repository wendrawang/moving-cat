import CoreGraphics
import Foundation

// MARK: - Feature Flags

enum CatFeatureFlags {

    /// Auto-walking saat idle terlalu lama.
    /// Logic walk TIDAK dihapus — set true (atau panggil
    /// CatOverlayManager.shared.setWalkingEnabled(true)) untuk mengaktifkan kembali.
    static let autoWalkingEnabled: Bool = false
}

// MARK: - Timing Constants

enum CatTimingConstants {

    /// Idle timer tick interval (seconds)
    static let idleTickInterval: TimeInterval = 1.0

    /// Idle → walking threshold (seconds)
    /// 8s = trigger walk 2s sebelum batas attention span 10s (Nielsen)
    static let idleToWalkThreshold: TimeInterval = 8.0

    /// Rotasi rest exercise (seconds) — setiap interval ini kucing ganti
    /// animasi warmup/pushup/starJump lain secara acak.
    /// ⚠ Harus < idleToWalkThreshold. Jika walking dipakai lagi nanti,
    /// naikkan nilai ini di atas threshold walk atau matikan rotasi —
    /// rotasi me-reset idle timer sehingga walking tidak akan pernah trigger.
    static let restRotationInterval: TimeInterval = 6.0

    /// Walking → back to idle threshold (seconds)
    static let walkToIdleThreshold: TimeInterval = 45.0

    /// Walk cycle edge-to-edge duration (seconds)
    static let walkCycleDuration: TimeInterval = 6.0

    /// Loading timer tick interval (seconds)
    static let loadingTickInterval: TimeInterval = 1.0

    /// Loading → exhausted threshold (seconds)
    /// 10s = Nielsen max attention span, sweet spot labor illusion effect (HBR 2011)
    static let loadingExhaustedThreshold: TimeInterval = 10.0

    // MARK: Reaction Durations

    /// Annoyed loop duration before auto-return (seconds)
    static let annoyedDuration: TimeInterval = 3.0

    /// Happy loop duration before auto-return (seconds)
    static let happyDuration: TimeInterval = 3.0

    /// Exhausted play-once duration — sesuaikan dengan durasi cat_exhausted.json
    static let exhaustedDuration: TimeInterval = 3.0
}

// MARK: - Layout Constants

enum CatLayoutConstants {
    static let avatarSize: CGFloat = 160.0
    static let bottomPadding: CGFloat = FrameSizes.MainTabBar.height
        + FrameSizes.MainTabBar.paddingBottom
        + Spaces.extraSmall
    static let walkingEdgePadding: CGFloat = 20.0
    static let walkHitSize: CGFloat = 128.0

    /// Jarak dari tepi layar yang dianggap "dibuang" saat drag (dismiss zone)
    static let dragDismissEdgeThreshold: CGFloat = 20.0

    /// Batas atas posisi Y kucing saat di-drag (jaga di bawah status bar area)
    static let dragTopMargin: CGFloat = 84.0
    static let defaultStartXRatio: CGFloat = 0.85
    static let speechBubbleOffsetY: CGFloat = -50.0
    static let envelopeBadgeSize: CGFloat = 24.0
    static let passportCornerRadius: CGFloat = 20.0
    static let overlayWindowLevel: CGFloat = 10000000.0
}

// MARK: - Stress Constants

enum CatStressConstants {

    /// Maximum stress cap
    static let maxStress: Int = 100

    /// For display normalization
    static let maxDisplayStress: Int = 100

    // MARK: Stress Modifiers

    /// Transaksi berhasil → stress -15
    static let transactionSuccessReduction: Int = -15

    /// Transaksi gagal → stress +10
    static let transactionFailedIncrease: Int = 10

    /// Loading exhausted → digantikan oleh patience system (applyPatienceStress)
    @available(*, deprecated, renamed: "stressDeltaFromPatience(_:)")
    static let exhaustedIncrease: Int = 20

    /// Ganti hari → stress -20 ("fresh day, fresh start")
    /// Tidak reset ke 0 supaya user stress tinggi tidak tiba-tiba "lupa"
    static let dailyDecay: Int = -20

    // MARK: Error-Specific Stress Increases

    /// HTTP 504 Gateway Timeout — server fault, lebih besar karena "salah kita"
    static let gatewayTimeoutIncrease: Int = 20

    /// HTTP 5xx non-504 — server error
    static let serverErrorIncrease: Int = 15

    /// Timeout / no connection — network issue, sama seperti failed biasa
    static let networkErrorIncrease: Int = 10

    // MARK: Voucher Triggers

    /// stress >= 90 → voucher (threshold normal)
    /// 90 = user sudah 3-5 kegagalan berturut; gestur maaf punya meaning di titik ini
    static let voucherStressThreshold: Int = 90

    /// Stress setelah claim voucher (bukan 0 — hindari perverse incentive farming)
    /// Reset ke 30 = fresh start tapi ada memory emosional tersisa
    static let stressAfterVoucherClaim: Int = 30

    /// Gateway timeout: threshold lebih rendah karena ini "salah server, bukan user"
    static let gatewayTimeoutVoucherThreshold: Int = 75

    /// Voucher trigger: exhausted >= 3x dalam 1 session ("3 strikes" rule — UX psychology)
    static let exhaustedSessionVoucherCount: Int = 3

    /// Cooldown 24 jam
    static let voucherCooldownInterval: TimeInterval = 86400.0

    // MARK: - Patience Decay System
    //
    // Setiap loading request dimulai dengan patience = 100.
    // Decay rate berubah progresif sesuai threshold Nielsen (0.1s / 1s / 10s).
    // Di akhir loading, patience dikonversi ke stress delta.

    /// Decay patience per tick berdasarkan elapsed time loading
    static func patienceDecayPerTick(elapsed: TimeInterval) -> Int {
        switch elapsed {
        case ..<3:  return 2    // 0-3s: user masih in flow
        case ..<6:  return 5    // 3-6s: user mulai sadar menunggu
        case ..<10: return 9    // 6-10s: user tidak sabar
        default:    return 15   // >10s: attention hilang (exhausted zone)
        }
    }

    /// Konversi patience → stress delta saat loading selesai
    static func stressDeltaFromPatience(_ patience: Int) -> Int {
        switch patience {
        case 80...100: return -5   // fast, user puas → kurangi stress
        case 60...79:  return 0    // normal, experience biasa
        case 40...59:  return 8    // mulai frustrasi
        case 20...39:  return 18   // frustrasi
        case 1...19:   return 30   // sangat frustrasi
        default:       return 50   // patience habis (0)
        }
    }
}

// MARK: - Animation Constants

enum CatAnimationConstants {
    static let springDamping: CGFloat = 0.6
    static let springResponse: Double = 0.5
}

// MARK: - Persistence Keys

enum CatPersistenceKeys {
    static let stressPoints = "cat_stress_points"
    static let voucherHistory = "cat_voucher_history"
    static let moodHistory = "cat_mood_history"
    static let lastSessionDate = "cat_last_session_date"
    static let lastVoucherGeneratedDate = "cat_last_voucher_date"
}
