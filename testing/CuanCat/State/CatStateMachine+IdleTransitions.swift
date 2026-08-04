import Foundation

// MARK: - Idle & Walk Transitions

extension CatStateMachine {

    func handleIdleTransitions(event: CatEvent) -> CatTransitionResult? {
        switch (currentState, event) {

        // ROTASI REST: setiap restRotationInterval, ganti ke exercise lain
        // (acak, dijamin beda dari yang sedang tampil). resetIdleTimer agar
        // siklus rotasi berulang terus. Tidak ada log/sound — ini bukan event,
        // hanya variasi visual (hindari spam mood history + UserDefaults write).
        // Case ini HARUS di atas case walking (interval 6s < walk threshold 8s).
        case (let state, .idleTimerTick(let elapsed))
            where state.isRestState
                && elapsed >= CatTimingConstants.restRotationInterval
                && elapsed < CatTimingConstants.idleToWalkThreshold:
            return CatTransitionResult(
                newState: restRotationProvider(currentState),
                sideEffects: [.resetIdleTimer]
            )

        // Rest (idle/warmup/pushup/starJump) cukup lama → mulai walking.
        // Hanya jalan jika auto-walking aktif (engine cek isWalkingEnabled sebelum tick).
        case (let state, .idleTimerTick(let elapsed))
            where state.isRestState
                && elapsed >= CatTimingConstants.idleToWalkThreshold:
            return CatTransitionResult(
                newState: .walking,
                sideEffects: [
                    .updateWalkDirection,
                    .logStateHistory(.walking),
                    .playSound(.walk)
                ]
            )

        // Walking cukup lama → kembali rest acak
        case (.walking, .idleTimerTick(let elapsed))
            where elapsed >= CatTimingConstants.walkToIdleThreshold:
            return CatTransitionResult(
                newState: restStateProvider(),
                sideEffects: [.setHomeBase, .resetIdleTimer, .startIdleTimer, .playSound(.idle)]
            )

        default:
            return nil
        }
    }
}
