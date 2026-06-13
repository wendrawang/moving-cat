import Combine
import Foundation
import SwiftUI
import UIKit

// MARK: - Cat Behavior Engine
//
// Central orchestrator: owns state machine, runs timers, publishes state.
// Extensions:
//   - CatBehaviorEngine+PublicAPI.swift    (transaction, voucher, drag, dismiss)
//   - CatBehaviorEngine+StateTransition.swift (forceState, processEvent, snap)
//   - CatBehaviorEngine+SideEffects.swift  (stress, voucher checks, haptic)
//   - CatBehaviorEngine+Timers.swift       (idle, loading, animation timers)
//   - CatBehaviorEngine+Walk.swift         (walk cycle, edge logic)

final class CatBehaviorEngine: ObservableObject {

    // MARK: - Published State

    @Published private(set) var currentState: CatState = .idle
    @Published private(set) var walkDirection: CatDirection = .right
    @Published var catPositionX: CGFloat = 0
    @Published var catPositionY: CGFloat = 0
    @Published private(set) var showVoucherEnvelope: Bool = false
    @Published private(set) var stressPoints: Int = 0
    @Published private(set) var isPassportVisible: Bool = false
    @Published private(set) var isVoucherOverlayVisible: Bool = false
    @Published private(set) var pendingVoucher: VoucherModel?
    @Published private(set) var isDismissed: Bool = false
    @Published var dragOffsetX: CGFloat = 0
    @Published var dragOffsetY: CGFloat = 0

    // MARK: - Home Position

    var homePositionX: CGFloat = 0
    var homePositionY: CGFloat = 0

    // MARK: - Internal Components

    let stateMachine = CatStateMachine()
    let persistence = CatPersistence()

    // MARK: - Timers (Combine)

    var idleTimerCancellable: AnyCancellable?
    var loadingTimerCancellable: AnyCancellable?
    var animationTimerCancellable: AnyCancellable?
    var dayChangeObserver: Any?

    var idleTimerReady: Bool = false
    var idleElapsedSeconds: TimeInterval = 0
    var loadingElapsedSeconds: TimeInterval = 0

    // MARK: - Loading State

    var isLoadingActive: Bool = false

    // MARK: - Voucher Tracking

    var lastVoucherGeneratedDate: Date?

    // MARK: - Patience

    var currentRequestPatience: Int = 100
    /// Flag agar applyPatienceStress tidak dieksekusi dua kali dalam satu request.
    /// Di-reset setiap startLoadingTimer (awal request baru).
    var patienceApplied: Bool = false

    // MARK: - Session Exhausted Counter

    var exhaustedCountThisSession: Int = 0

    // MARK: - Screen Dimensions

    let screenWidth: CGFloat
    let screenHeight: CGFloat

    // MARK: - Walk State

    var walkTargetX: CGFloat = 0
    var walkTimerCancellable: AnyCancellable?
    var walkAnimStartX: CGFloat = 0
    var walkAnimStartTime: Date = Date()
    var walkAnimDuration: TimeInterval = 0

    // MARK: - Drag State

    var isDragging: Bool = false

    // MARK: - Dismiss Side Memory
    // Sisi layar tempat kucing terakhir di-dismiss.
    // true = kanan, false = kiri. Default kanan karena posisi awal di kanan (0.85).
    var lastDismissedFromRight: Bool = true

    // MARK: - Haptic Generators (cached untuk hindari latency tiap panggilan)

    let impactLight = UIImpactFeedbackGenerator(style: .light)
    let impactMedium = UIImpactFeedbackGenerator(style: .medium)
    let notificationGenerator = UINotificationFeedbackGenerator()

    // MARK: - History

    private(set) var moodHistory: [MoodHistoryEntry] = []
    private(set) var voucherHistory: [VoucherModel] = []

    // MARK: - Init

    init() {
        let bounds = UIScreen.main.bounds
        self.screenWidth = bounds.width
        self.screenHeight = bounds.height

        let defaultHomeX = bounds.width * CatLayoutConstants.defaultStartXRatio
        let defaultHomeY = bounds.height - CatLayoutConstants.bottomPadding
        self.homePositionX = defaultHomeX
        self.homePositionY = defaultHomeY
        self.catPositionX = defaultHomeX
        self.catPositionY = defaultHomeY

        loadPersistedData()
//        startIdleTimer()
        observeDayChange()
    }
    
    func markReadyAndStartTimer() {
        guard !idleTimerReady else { return }
        idleTimerReady = true
        CatAudioManager.shared.play(.idle)
        startIdleTimer()
    }

    // MARK: - Persistence Loading

    private func loadPersistedData() {
        stressPoints = persistence.loadStressPoints()
        moodHistory = persistence.loadMoodHistory()
        voucherHistory = persistence.loadVoucherHistory()
        lastVoucherGeneratedDate = persistence.loadLastVoucherDate()

        if let lastDate = persistence.loadLastSessionDate() {
            if !Calendar.current.isDateInToday(lastDate) {
                stressPoints = max(0, stressPoints + CatStressConstants.dailyDecay)
                persistence.saveStressPoints(stressPoints)
            }
        }
        persistence.saveLastSessionDate(Date())
        checkAndShowVoucher()
    }

    private func observeDayChange() {
        dayChangeObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.significantTimeChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.processEvent(.dayChanged)
        }
    }

    // MARK: - Walking Enable / Disable

    private(set) var isWalkingEnabled: Bool = true

    func setWalkingEnabled(_ enabled: Bool) {
        isWalkingEnabled = enabled
        if enabled { idleElapsedSeconds = 0 }
    }

    // MARK: - Loading Type

    private(set) var currentLoadingType: CatLoadingType = .silent

    func handleLoadingStarted(_ type: CatLoadingType = .silent) {
        isLoadingActive = true
        currentLoadingType = type
        stateMachine.isExhaustedEnabled = (type == .tracked)
        processEvent(.loadingStarted)
    }

    func handleLoadingStopped() {
        guard isLoadingActive else { return }
        isLoadingActive = false
        processEvent(.loadingStopped)
    }

    // MARK: - Internal Setters for private(set) vars

    func setPendingVoucher(_ voucher: VoucherModel?) { pendingVoucher = voucher }
    func setIsVoucherOverlayVisible(_ visible: Bool) { isVoucherOverlayVisible = visible }
    func setIsPassportVisible(_ visible: Bool) { isPassportVisible = visible }
    func setIsDismissed(_ val: Bool) { isDismissed = val }

    // MARK: - Mutable Setters

    func setCurrentState(_ state: CatState) { currentState = state }
    func setCatPositionX(_ val: CGFloat) { catPositionX = val }
    func setCatPositionY(_ val: CGFloat) { catPositionY = val }
    func setWalkDirection(_ dir: CatDirection) { walkDirection = dir }
    func setShowVoucherEnvelope(_ val: Bool) { showVoucherEnvelope = val }

    func updateStressPoints(_ val: Int) {
        withAnimation(.easeInOut(duration: 0.8)) {
            stressPoints = val
        }
        persistence.saveStressPoints(val)
    }

    func appendVoucherHistory(_ voucher: VoucherModel) {
        voucherHistory.append(voucher)
    }

    func appendMoodHistory(_ entry: MoodHistoryEntry) {
        moodHistory.append(entry)
        let maxEntries = 50
        if moodHistory.count > maxEntries {
            moodHistory = Array(moodHistory.suffix(maxEntries))
        }
        persistence.saveMoodHistory(moodHistory)
    }

    // MARK: - Cleanup

    func cleanup() {
        CatAudioManager.shared.stopAll()
        walkTimerCancellable?.cancel()
        idleTimerCancellable?.cancel()
        loadingTimerCancellable?.cancel()
        animationTimerCancellable?.cancel()

        if let observer = dayChangeObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    deinit { cleanup() }
}
