import Foundation

// MARK: - Transaction Transitions

extension CatStateMachine {

    func handleTransactionTransitions(
        event: CatEvent
    ) -> CatTransitionResult? {
        switch (currentState, event) {

        // Transaksi berhasil → happy
        case (_, .transactionSuccess):
            var effects: [CatSideEffect] = []
            if currentState == .exhausted {
                effects.append(.stopLoadingTimer)
            }
            effects.append(contentsOf: [
                .stopIdleTimer,
                .playHapticFeedback(.success),
                .playSound(.happy),
                .scheduleAnimationEnd(CatTimingConstants.happyDuration),
                .logStateHistory(.happy),
                .applyStressDelta(CatStressConstants.transactionSuccessReduction)
            ])
            return CatTransitionResult(
                newState: .happy, sideEffects: effects
            )

        // Transaksi gagal → annoyed
        case (_, .transactionFailed):
            return makeFailedTransition(targetState: .annoyed)

        // Transaksi gagal (variant sad) → sad
        case (_, .transactionFailedSad):
            return makeFailedTransition(targetState: .sad)

        default:
            return nil
        }
    }

    private func makeFailedTransition(targetState: CatState) -> CatTransitionResult {
        var effects: [CatSideEffect] = []
        if currentState == .exhausted {
            effects.append(.stopLoadingTimer)
        }
        // Stress TIDAK diaplikasikan di sini — caller yang bertanggung jawab.
        // handleTransactionFailed  → applyStressDelta(+10) sebelum processEvent.
        // handleTransactionError   → applyStressDelta(error-specific) sebelum processEvent.
        // Kalau stress ada di sini juga, reportError(.gatewayTimeout) jadi +30 bukan +20,
        // dan reportError(.clientError) jadi +10 bukan +0.
        let sound: CatSoundType = (targetState == .sad) ? .sad : .annoyed
        effects.append(contentsOf: [
            .stopIdleTimer,
            .playHapticFeedback(.warning),
            .playSound(sound),
            .scheduleAnimationEnd(CatTimingConstants.annoyedDuration),
            .logStateHistory(targetState)
        ])
        return CatTransitionResult(newState: targetState, sideEffects: effects)
    }
}
