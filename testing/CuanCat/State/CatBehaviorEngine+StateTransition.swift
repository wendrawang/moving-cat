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
            updateHomeBase()
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
    }

    // MARK: - Visual Position

    /// Posisi visual X saat ini (memperhitungkan animasi walk / glide spotlight
    /// yang sedang jalan). Digunakan PassThroughWindow untuk hit testing.
    var currentVisualX: CGFloat {
        if let glide = spotlightGlideVisualPosition {
            return glide.x
        }
        guard currentState == .walking, walkAnimDuration > 0 else {
            return catPositionX
        }
        let elapsed = Date().timeIntervalSince(walkAnimStartTime)
        let progress = min(CGFloat(elapsed / walkAnimDuration), 1.0)
        return walkAnimStartX + (walkTargetX - walkAnimStartX) * progress
    }

    /// Posisi visual Y — hanya glide spotlight yang menganimasikan Y.
    var currentVisualY: CGFloat {
        spotlightGlideVisualPosition?.y ?? catPositionY
    }

    /// BUG-05 fix: gunakan withTransaction(disablesAnimations: true) untuk
    /// benar-benar membatalkan animasi SwiftUI yang sedang berjalan.
    func snapToCurrentWalkPosition() {
        guard walkAnimDuration > 0 else { return }
        let elapsed = Date().timeIntervalSince(walkAnimStartTime)
        let progress = min(CGFloat(elapsed / walkAnimDuration), 1.0)
        let interpolated = walkAnimStartX + (walkTargetX - walkAnimStartX) * progress
        var transaction = SwiftUI.Transaction()
        transaction.disablesAnimations = true
        SwiftUI.withTransaction(transaction) {
            self.setCatPositionX(interpolated)
        }
    }
}
