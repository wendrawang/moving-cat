import Foundation
import UIKit

// MARK: - Side Effect Execution

extension CatBehaviorEngine {

    func executeSideEffects(_ effects: [CatSideEffect]) {
        for effect in effects {
            executeSingleEffect(effect)
        }
    }

    private func executeSingleEffect(_ effect: CatSideEffect) {
        switch effect {
        // Timer
        case .resetIdleTimer:
            idleElapsedSeconds = 0
        case .startIdleTimer:
            startIdleTimer()
        case .stopIdleTimer:
            stopIdleTimer()
        case .startLoadingTimer:
            startLoadingTimer()
        case .stopLoadingTimer:
            stopLoadingTimer()
        case .scheduleAnimationEnd(let duration):
            scheduleAnimationEnd(after: duration)

        // Stress
        case .applyStressDelta(let delta):
            applyStressDelta(delta)
        case .checkVoucherThreshold:
            checkAndShowVoucher()
        case .checkVoucherEarlyThreshold:
            checkAndShowVoucherEarly()

        // Patience
        case .applyPatienceStress:
            guard !patienceApplied else { break }
            patienceApplied = true
            let delta = CatStressConstants.stressDeltaFromPatience(currentRequestPatience)
            applyStressDelta(delta)

        // Session tracking
        case .incrementExhaustedCount:
            exhaustedCountThisSession += 1
        case .resetExhaustedCount:
            exhaustedCountThisSession = 0

        // Walk
        case .updateWalkDirection:
            startWalkCycle()
        case .setHomeBase:
            updateHomeBase()

        // Logging
        case .logStateHistory(let state):
            logStateEntry(state: state)

        // Haptic
        case .playHapticFeedback(let style):
            playHaptic(style)

        // Sound
        case .playSound(let type):
            CatAudioManager.shared.play(type)
        }
    }

    // MARK: - Stress

    func applyStressDelta(_ delta: Int) {
        let newStress = max(
            0, min(stressPoints + delta, CatStressConstants.maxStress)
        )
        updateStressPoints(newStress)
    }

    // MARK: - Voucher

    func checkAndShowVoucher() {
        guard !showVoucherEnvelope else { return }
        let byStress = stressPoints >= CatStressConstants.voucherStressThreshold
        let byExhausted = exhaustedCountThisSession >= CatStressConstants.exhaustedSessionVoucherCount
        if byStress || byExhausted {
            tryShowVoucher()
        }
    }

    /// Gateway timeout: threshold lebih rendah (75) karena ini "salah server, bukan user"
    func checkAndShowVoucherEarly() {
        guard !showVoucherEnvelope else { return }
        if stressPoints >= CatStressConstants.gatewayTimeoutVoucherThreshold {
            tryShowVoucher()
        }
    }

    func tryShowVoucher() {
        guard !showVoucherEnvelope else { return }
        guard VoucherModel.canGenerateVoucher(
            lastGeneratedDate: lastVoucherGeneratedDate
        ) else { return }
        setShowVoucherEnvelope(true)
    }

    // MARK: - Logging

    func logStateEntry(state: CatState) {
        let entry = MoodHistoryEntry(state: state, stress: stressPoints)
        appendMoodHistory(entry)
    }

    // MARK: - Haptic

    func playHaptic(_ style: HapticStyle) {
        switch style {
        case .light:
            impactLight.impactOccurred()
        case .medium:
            impactMedium.impactOccurred()
        case .success:
            notificationGenerator.notificationOccurred(.success)
        case .warning:
            notificationGenerator.notificationOccurred(.warning)
        }
    }
}
