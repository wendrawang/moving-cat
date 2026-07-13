import Foundation
import SwiftUI

// MARK: - State Transitions & Force State

extension CatBehaviorEngine {

    // MARK: - Force State (Demo Only)

    func forceState(_ state: CatState) {
        if currentState == .walking {
            snapToCurrentWalkPosition()
        }

        stopIdleTimer()
        stopLoadingTimer()
        stopWalkTimer()
        cancelPendingAnimations()

        setCurrentState(state)
        stateMachine.applyTransition(
            CatTransitionResult(newState: state, sideEffects: [])
        )

        switch state {
        case .idle, .warmup, .pushup, .starJump:
            // Demo: tampilkan langsung di spotlight (looping exercise).
            showInSpotlight()
            startIdleTimer()
        case .walking:
            startWalkCycle()
        case .happy:
            snapToSpotlightForReaction()
            scheduleAnimationEnd(after: CatTimingConstants.happyDuration)
        case .annoyed, .sad:
            snapToSpotlightForReaction()
            scheduleAnimationEnd(after: CatTimingConstants.annoyedDuration)
        case .exhausted:
            snapToSpotlightForReaction()
            scheduleAnimationEnd(after: CatTimingConstants.exhaustedDuration)
        }
    }

    // MARK: - Core Event Processing

    func processEvent(_ event: CatEvent) {
        guard let result = stateMachine.transition(event: event) else { return }
        let oldState = currentState
        stateMachine.applyTransition(result)

        if oldState == .walking && result.newState != .walking {
            snapToCurrentWalkPosition()
            stopWalkTimer()
        }

        if currentState != result.newState {
            setCurrentState(result.newState)
        }

        // Reaction (annoyed/sad/happy/exhausted) tampil di spotlight sejak muncul
        if result.newState.isTransientReaction && oldState != result.newState {
            snapToSpotlightForReaction()
        }

        executeSideEffects(result.sideEffects)

        // Reaction selesai main sekali → kembali ke rest. Jika idle-spotlight
        // nonaktif (bukan di page yang mengizinkan looping), sembunyikan kucing
        // alih-alih ikut looping exercise.
        if oldState.isTransientReaction
            && result.newState.isRestState
            && !isIdleAnimationEnabled {
            hideFromSpotlight()
        }
    }

    // MARK: - Visual Position

    /// Posisi visual X saat ini (memperhitungkan animasi walk yang sedang
    /// jalan). Digunakan PassThroughWindow untuk hit testing.
    var currentVisualX: CGFloat {
        guard currentState == .walking, walkAnimationDuration > 0 else {
            return catPositionX
        }
        let elapsed = Date().timeIntervalSince(walkAnimationStartTime)
        let progress = min(CGFloat(elapsed / walkAnimationDuration), 1.0)
        return walkAnimationStartX + (walkTargetX - walkAnimationStartX) * progress
    }

    /// Posisi visual Y — kucing spotlight tidak menganimasikan posisi Y
    /// (muncul via fade), jadi cukup posisi published.
    var currentVisualY: CGFloat { catPositionY }

    /// BUG-05 fix: gunakan withTransaction(disablesAnimations: true) untuk
    /// benar-benar membatalkan animasi SwiftUI yang sedang berjalan.
    func snapToCurrentWalkPosition() {
        guard walkAnimationDuration > 0 else { return }
        let elapsed = Date().timeIntervalSince(walkAnimationStartTime)
        let progress = min(CGFloat(elapsed / walkAnimationDuration), 1.0)
        let interpolated = walkAnimationStartX + (walkTargetX - walkAnimationStartX) * progress
        var transaction = SwiftUI.Transaction()
        transaction.disablesAnimations = true
        SwiftUI.withTransaction(transaction) {
            self.setCatPositionX(interpolated)
        }
    }
}
