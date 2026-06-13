import Foundation
import SwiftUI
import UIKit

// MARK: - Drag, Dismiss & Bring Back
//
// Drag punya 2 hasil:
//   1. Lepas di tengah layar → posisi kucing di-commit di titik lepas (reposisi).
//   2. Lepas / lewat dekat tepi layar → kucing dibuang (dismiss).
//
// Bring back: kucing langsung muncul di homebase default kanan-bawah,
// TANPA animasi berjalan masuk. Versi walk-in lama disimpan di
// bringBackWithWalk() — tinggal dipakai jika dibutuhkan lagi.

extension CatBehaviorEngine {

    // MARK: - Drag Gesture

    func handleDragChanged(translation: CGSize) {
        guard !isDismissed else { return }

        if !isDragging {
            isDragging = true
            if currentState == .walking {
                snapToCurrentWalkPosition()
            }
            stopWalkTimer()
            stopIdleTimer()
        }

        withAnimation(nil) {
            self.dragOffsetX = translation.width
            self.dragOffsetY = translation.height
        }

        let finalX = catPositionX + translation.width
        let finalY = catPositionY + translation.height
        if isNearScreenEdge(posX: finalX, posY: finalY) {
            dismiss()
        }
    }

    func handleDragEnded(translation: CGSize) {
        let wasDismissed = isDismissed
        isDragging = false

        if wasDismissed { return }

        let finalX = catPositionX + translation.width
        let finalY = catPositionY + translation.height

        if isNearScreenEdge(posX: finalX, posY: finalY) {
            dismiss()
            return
        }

        commitDragPosition(finalX: finalX, finalY: finalY)
        startIdleTimer()
    }

    /// Commit posisi baru hasil drag — kucing menetap di titik lepas
    /// (di-clamp agar tetap aman di dalam layar). Homebase ikut pindah.
    private func commitDragPosition(finalX: CGFloat, finalY: CGFloat) {
        let clampedX = min(max(finalX, walkLeftEdge), walkRightEdge)
        let minY = CatLayoutConstants.dragTopMargin
        let maxY = screenHeight - CatLayoutConstants.bottomPadding
        let clampedY = min(max(finalY, minY), maxY)

        // disablesAnimations: posisi + offset berubah dalam 1 frame yang sama,
        // tanpa animasi implicit — tidak ada visual jump/lag saat lepas drag.
        var transaction = SwiftUI.Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            self.catPositionX = clampedX
            self.catPositionY = clampedY
            self.dragOffsetX = 0
            self.dragOffsetY = 0
        }
        updateHomeBase()
    }

    func isNearScreenEdge(posX: CGFloat, posY: CGFloat) -> Bool {
        let threshold = CatLayoutConstants.dragDismissEdgeThreshold
        return posX < threshold
            || posX > screenWidth - threshold
            || posY < threshold
            || posY > screenHeight - threshold
    }

    // MARK: - Dismiss

    func dismiss() {
        // Catat sisi berdasarkan posisi efektif saat dismiss (termasuk drag offset aktif).
        let effectiveX = catPositionX + dragOffsetX
        lastDismissedFromRight = effectiveX > screenWidth / 2

        setIsDismissed(true)
        withAnimation(nil) {
            self.dragOffsetX = 0
            self.dragOffsetY = 0
        }
        cancelPendingAnimations()
        stopIdleTimer()
        stopWalkTimer()
        CatAudioManager.shared.stopLoop()
    }

    // MARK: - Bring Back (instan, tanpa walk-in)

    func bringBack() {
        guard isDismissed else { return }
        setIsDismissed(false)
        cancelPendingAnimations()

        // Langsung muncul di homebase default kanan-bawah — tanpa animasi masuk.
        let defaultHomeX = screenWidth * CatLayoutConstants.defaultStartXRatio
        let defaultHomeY = screenHeight - CatLayoutConstants.bottomPadding

        var transaction = SwiftUI.Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            self.catPositionX = defaultHomeX
            self.catPositionY = defaultHomeY
        }
        homePositionX = defaultHomeX
        homePositionY = defaultHomeY

        setWalkDirection(.right)
        let restState = stateMachine.nextRestState()
        setCurrentState(restState)
        stateMachine.applyTransition(CatTransitionResult(newState: restState, sideEffects: []))
        CatAudioManager.shared.play(.idle)
        startIdleTimer()
    }

    // MARK: - Bring Back (legacy walk-in — disimpan untuk dipakai sewaktu-waktu)

    /// Versi lama: kucing masuk berjalan dari sisi tempat dia di-dismiss.
    /// Tidak dipanggil saat ini — ganti pemanggilan bringBack() ke method ini
    /// jika animasi walk-in dibutuhkan lagi.
    func bringBackWithWalk() {
        guard isDismissed else { return }
        setIsDismissed(false)

        // Masuk dari sisi yang sama dengan sisi dismiss — kucing keluar kanan, masuk kanan.
        let offScreenX: CGFloat = lastDismissedFromRight
            ? screenWidth + CatLayoutConstants.avatarSize
            : -CatLayoutConstants.avatarSize

        withAnimation(nil) {
            self.catPositionX = offScreenX
            self.catPositionY = self.homePositionY
        }

        setCurrentState(.walking)
        stateMachine.applyTransition(CatTransitionResult(newState: .walking, sideEffects: []))
        setWalkDirection(lastDismissedFromRight ? .left : .right)
        CatAudioManager.shared.play(.walk)

        // Homebase di sisi yang sama dengan sisi masuk:
        // kanan → berhenti di 85% layar, kiri → berhenti di 15% layar (simetris).
        walkTargetX = lastDismissedFromRight
            ? screenWidth * CatLayoutConstants.defaultStartXRatio
            : screenWidth * (1.0 - CatLayoutConstants.defaultStartXRatio)

        startEnterSceneWalk()
    }
}
