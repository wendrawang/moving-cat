import Foundation

// MARK: - Cat State Machine (Pure)

/// Pure state machine — compute transitions + declare side effects.
/// BehaviorEngine executes the side effects.
final class CatStateMachine {

    private(set) var currentState: CatState = .idle

    /// Dikontrol engine berdasarkan CatLoadingType.
    /// Default false: exhausted hanya aktif setelah .tracked dikonsumsi dari handleLoadingStarted.
    var isExhaustedEnabled: Bool = false

    func transition(event: CatEvent) -> CatTransitionResult? {
        return handleIdleTransitions(event: event)
            ?? handleLoadingTransitions(event: event)
            ?? handleTransactionTransitions(event: event)
            ?? handleAnimationTransitions(event: event)
    }

    func applyTransition(_ result: CatTransitionResult) {
        currentState = result.newState
    }

    // MARK: - Animation / System Transitions

    private func handleAnimationTransitions(
        event: CatEvent
    ) -> CatTransitionResult? {
        switch (currentState, event) {

        // Exhausted HARUS di atas case isTransientReaction — kedua case sama-sama
        // match (.exhausted, .animationFinished), tapi exhausted butuh stopLoadingTimer
        // agar timer tidak terus tick dan langsung trigger exhausted lagi.
        case (.exhausted, .animationFinished):
            return CatTransitionResult(
                newState: .idle,
                sideEffects: [.stopLoadingTimer, .setHomeBase, .resetIdleTimer, .startIdleTimer, .playSound(.idle)]
            )

        // Transient reactions (annoyed/happy/sad/exhausted) → idle after timer
        case (_, .animationFinished) where currentState.isTransientReaction:
            return CatTransitionResult(
                newState: .idle,
                sideEffects: [.setHomeBase, .resetIdleTimer, .startIdleTimer, .playSound(.idle)]
            )

        // Day changed → stress decay + reset exhausted session counter
        case (_, .dayChanged):
            return CatTransitionResult(
                newState: currentState,
                sideEffects: [
                    .applyStressDelta(CatStressConstants.dailyDecay),
                    .resetExhaustedCount
                ]
            )

        // BUG-04 fix: voucherClaimed → transisi ke idle + restart idle timer.
        // Sebelumnya return nil, menyebabkan idle timer tidak pernah restart
        // jika kucing sedang dalam state annoyed/happy saat voucher diklaim.
        case (_, .voucherClaimed):
            return CatTransitionResult(
                newState: .idle,
                sideEffects: [.setHomeBase, .resetIdleTimer, .startIdleTimer, .playSound(.idle)]
            )

        default:
            return nil
        }
    }
}
