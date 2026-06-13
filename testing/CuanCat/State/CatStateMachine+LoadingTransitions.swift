import Foundation

// MARK: - Loading Flow Transitions
//
// loadingStarted → idle tetap (timer mulai)
// loading > 5s → exhausted
// loadingStopped → idle

extension CatStateMachine {

    func handleLoadingTransitions(event: CatEvent) -> CatTransitionResult? {
        switch (currentState, event) {

        // Start loading → mulai timer, tetap di state saat ini
        case (_, .loadingStarted) where currentState != .exhausted:
            return CatTransitionResult(
                newState: currentState,
                sideEffects: [.startLoadingTimer]
            )

        // Loading >= 10s → exhausted
        // Guard: isExhaustedEnabled = false saat CatLoadingType.silent → skip exhausted.
        // Stress dihitung dari patience (bukan flat +20) — lebih nuanced.
        // Increment exhausted counter untuk trigger voucher setelah 3x.
        case (_, .loadingTimerTick(let elapsed))
            where elapsed >= CatTimingConstants.loadingExhaustedThreshold
                && currentState != .exhausted
                && isExhaustedEnabled:
            return CatTransitionResult(
                newState: .exhausted,
                sideEffects: [
                    .stopIdleTimer,
                    .applyPatienceStress,           // patience → stress delta
                    .incrementExhaustedCount,        // +1 session counter
                    .checkVoucherThreshold,          // cek 90 threshold ATAU 3x exhausted
                    .logStateHistory(.exhausted),
                    .playSound(.exhausted),
                    .scheduleAnimationEnd(CatTimingConstants.exhaustedDuration)
                ]
            )

        // Loading stopped saat exhausted → idle
        // Patience sudah di-konversi saat transisi ke exhausted, tidak perlu lagi.
        case (.exhausted, .loadingStopped):
            return CatTransitionResult(
                newState: .idle,
                sideEffects: [
                    .stopLoadingTimer,
                    .setHomeBase,
                    .resetIdleTimer,
                    .startIdleTimer,
                    .playSound(.idle)
                ]
            )

        // Loading stopped sebelum exhausted → tetap state, apply patience stress
        case (_, .loadingStopped):
            return CatTransitionResult(
                newState: currentState,
                sideEffects: [
                    .stopLoadingTimer,
                    .applyPatienceStress,    // konversi patience → stress
                    .checkVoucherThreshold   // cek apakah stress sudah trigger voucher
                ]
            )

        default:
            return nil
        }
    }
}
