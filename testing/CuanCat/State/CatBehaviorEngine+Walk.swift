import Combine
import Foundation
import SwiftUI
import UIKit

// MARK: - Walk Cycle
//
// Smooth walking via single withAnimation — GPU-interpolated, zero gaps.
//
// Pattern (1 animation per cycle):
//   Dari posisi saat ini, jalan ke edge terjauh.
//   Sampai di edge → idle. Cycle berikutnya, jalan ke edge berlawanan.
//
// Speed konstan: duration = distance / speed.
// Homebase = posisi terakhir kucing saat idle (updated setiap transisi ke idle).

extension CatBehaviorEngine {

    var walkLeftEdge: CGFloat {
        CatLayoutConstants.walkingEdgePadding + CatLayoutConstants.walkHitSize / 2
    }

    var walkRightEdge: CGFloat {
        screenWidth - CatLayoutConstants.walkingEdgePadding - CatLayoutConstants.walkHitSize / 2
    }

    private var walkSpeed: CGFloat {
        let totalWidth = walkRightEdge - walkLeftEdge
        guard totalWidth > 0 else { return 50 }
        return totalWidth / CGFloat(CatTimingConstants.walkCycleDuration)
    }

    private func walkDuration(from startX: CGFloat, to endX: CGFloat) -> TimeInterval {
        let distance = abs(endX - startX)
        guard walkSpeed > 0 else { return 1.0 }
        return TimeInterval(distance / walkSpeed)
    }

    func updateHomeBase() {
        homePositionX = catPositionX
        homePositionY = catPositionY
    }

    // MARK: - Start Walk

    func startWalkCycle() {
        stopWalkTimer()

        let distToLeft = catPositionX - walkLeftEdge
        let distToRight = walkRightEdge - catPositionX

        if distToLeft >= distToRight {
            walkTargetX = walkLeftEdge
            setWalkDirection(.left)
        } else {
            walkTargetX = walkRightEdge
            setWalkDirection(.right)
        }

        // Jika sudah di edge target → pilih edge berlawanan
        if abs(catPositionX - walkTargetX) < 2.0 {
            if walkTargetX <= walkLeftEdge + 1 {
                walkTargetX = walkRightEdge
                setWalkDirection(.right)
            } else {
                walkTargetX = walkLeftEdge
                setWalkDirection(.left)
            }
        }

        animateToTarget()
    }

    // MARK: - Core Animation

    private func animateToTarget() {
        let startX = catPositionX
        let target = walkTargetX
        let duration = walkDuration(from: startX, to: target)

        guard duration > 0.05 else {
            setCatPositionX(target)
            transitionToIdle()
            return
        }

        walkAnimStartX = startX
        walkAnimStartTime = Date()
        walkAnimDuration = duration

        withAnimation(.linear(duration: duration)) {
            self.setCatPositionX(target)
        }

        // Fire 50ms sebelum animasi selesai agar state idle sudah aktif
        // sebelum cat berhenti visual — menghindari "walk animation while stopped".
        // Sisa 50ms: cat masih bergerak < 2pt (tidak terlihat).
        let transitionDelay = max(0, duration - 0.05)
        walkTimerCancellable?.cancel()
        walkTimerCancellable = Just(())
            .delay(for: .seconds(transitionDelay), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self = self, self.currentState == .walking else { return }
                self.transitionToIdle()
            }
    }

    // MARK: - Transition to Idle

    private func transitionToIdle() {
        stopWalkTimer()

        // Snap ke exact target dulu sebelum ubah state — pastikan tidak ada
        // posisi animation yang masih berjalan saat state sudah idle.
        // Tanpa ini, cat bergerak 50ms dalam idle state (state desync visual).
        var transaction = SwiftUI.Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) { self.setCatPositionX(self.walkTargetX) }

        setCurrentState(.idle)
        stateMachine.applyTransition(
            CatTransitionResult(newState: .idle, sideEffects: [])
        )
        CatAudioManager.shared.play(.idle)
        updateHomeBase()
        idleElapsedSeconds = 0
        startIdleTimer()
    }

    // MARK: - Enter Scene Walk

    func startEnterSceneWalk() {
        stopWalkTimer()
        animateToTarget()
    }

    // MARK: - Stop

    func stopWalkTimer() {
        walkTimerCancellable?.cancel()
        walkTimerCancellable = nil
    }
}
