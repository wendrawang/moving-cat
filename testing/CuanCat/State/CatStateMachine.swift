import Foundation

// MARK: - Cat Rest Rotation Bag
//
// Shuffle-bag: jamin KETIGA exercise (warmup/pushup/starJump) muncul semua
// sebelum ada yang berulang. Random biasa (excluding current) bisa bolak-balik
// 2 animasi saja kalau tidak hoki. Bag di-refill dengan urutan shuffle baru
// setiap isinya habis.

final class CatRestRotationBag {

    private var queue: [CatState] = []

    /// Ambil rest state berikutnya dari bag.
    /// `current` dipakai mencegah repeat di sambungan antar ronde
    /// (akhir ronde lama == awal ronde baru) — kepala bag dipindah ke belakang.
    func next(after current: CatState) -> CatState {
        if queue.isEmpty {
            queue = CatState.restPool.shuffled()
        }
        if queue.first == current, queue.count > 1 {
            queue.append(queue.removeFirst())
        }
        return queue.removeFirst()
    }
}

// MARK: - Cat State Machine (Pure)

/// Pure state machine — compute transitions + declare side effects.
/// BehaviorEngine executes the side effects.
final class CatStateMachine {

    private(set) var currentState: CatState = .idle

    /// Dikontrol engine berdasarkan CatLoadingType.
    /// Default false: exhausted hanya aktif setelah .tracked dikonsumsi dari handleLoadingStarted.
    var isExhaustedEnabled: Bool = false

    /// Shuffle-bag bersama — SEMUA jalur menuju rest (rotasi, selesai reaksi,
    /// selesai walking, voucher, bringBack, state awal) menarik dari bag yang
    /// sama, sehingga rotasi penuh tetap terjaga meski diinterupsi transaksi.
    let restRotationBag = CatRestRotationBag()

    /// Provider rest state tujuan transisi (default: tarik dari shuffle-bag).
    /// Injectable (lazy var) agar unit test bisa deterministic.
    lazy var restStateProvider: () -> CatState = { [weak self] in
        guard let self = self else { return CatState.randomRest() }
        return self.restRotationBag.next(after: self.currentState)
    }

    /// Provider untuk ROTASI rest — dijamin beda dari state saat ini.
    lazy var restRotationProvider: (CatState) -> CatState = { [weak self] current in
        self?.restRotationBag.next(after: current)
            ?? CatState.randomRest(excluding: current)
    }

    /// Helper untuk engine (state awal, walk selesai, bringBack).
    func nextRestState() -> CatState { restStateProvider() }

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
                newState: restStateProvider(),
                sideEffects: [.stopLoadingTimer, .setHomeBase, .resetIdleTimer, .startIdleTimer, .playSound(.idle)]
            )

        // Transient reactions (annoyed/happy/sad/exhausted) → rest acak after timer
        case (_, .animationFinished) where currentState.isTransientReaction:
            return CatTransitionResult(
                newState: restStateProvider(),
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

        // BUG-04 fix: voucherClaimed → transisi ke rest + restart idle timer.
        // Sebelumnya return nil, menyebabkan idle timer tidak pernah restart
        // jika kucing sedang dalam state annoyed/happy saat voucher diklaim.
        case (_, .voucherClaimed):
            return CatTransitionResult(
                newState: restStateProvider(),
                sideEffects: [.setHomeBase, .resetIdleTimer, .startIdleTimer, .playSound(.idle)]
            )

        default:
            return nil
        }
    }
}
