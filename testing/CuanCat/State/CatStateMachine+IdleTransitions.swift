import Foundation

// MARK: - Idle & Walk Transitions

extension CatStateMachine {

    func handleIdleTransitions(event: CatEvent) -> CatTransitionResult? {
        switch (currentState, event) {

        // Idle cukup lama → mulai walking
        case (.idle, .idleTimerTick(let elapsed))
            where elapsed >= CatTimingConstants.idleToWalkThreshold:
            return CatTransitionResult(
                newState: .walking,
                sideEffects: [
                    .updateWalkDirection,
                    .logStateHistory(.walking),
                    .playSound(.walk)
                ]
            )

        // Walking cukup lama → kembali idle
        case (.walking, .idleTimerTick(let elapsed))
            where elapsed >= CatTimingConstants.walkToIdleThreshold:
            return CatTransitionResult(
                newState: .idle,
                sideEffects: [.setHomeBase, .resetIdleTimer, .startIdleTimer, .playSound(.idle)]
            )

        default:
            return nil
        }
    }
}
