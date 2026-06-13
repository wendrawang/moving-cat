import Foundation
import SwiftUI
import UIKit

// MARK: - Transaction & Voucher Public API

extension CatBehaviorEngine {

    // MARK: - Transaction

    func handleTransactionSuccess() {
        processEvent(.transactionSuccess)
    }

    func handleTransactionFailed() {
        applyStressDelta(CatStressConstants.transactionFailedIncrease)
        processEvent(randomFailedEvent())
    }

    /// Random 50/50 antara annoyed dan sad saat transaksi gagal.
    private func randomFailedEvent() -> CatEvent {
        Bool.random() ? .transactionFailed : .transactionFailedSad
    }

    func handleTransactionError(_ errorType: CatTransactionError) {
        switch errorType {
        case .gatewayTimeout:
            applyStressDelta(CatStressConstants.gatewayTimeoutIncrease)
            checkAndShowVoucherEarly()
        case .serverError:
            applyStressDelta(CatStressConstants.serverErrorIncrease)
            checkAndShowVoucher()
        case .networkError:
            applyStressDelta(CatStressConstants.networkErrorIncrease)
            checkAndShowVoucher()
        case .clientError:
            break
        case .unknown:
            applyStressDelta(CatStressConstants.transactionFailedIncrease)
            checkAndShowVoucher()
        }
        processEvent(randomFailedEvent())
    }

    // MARK: - Voucher

    func handleVoucherTapped() {
        guard showVoucherEnvelope else { return }
        let voucher = VoucherModel(voucherType: .apology)
        setPendingVoucher(voucher)
        setShowVoucherEnvelope(false)
        withAnimation(.easeOut(duration: 0.3)) {
            self.setIsVoucherOverlayVisible(true)
        }
    }

    func handleVoucherClaim() {
        guard var voucher = pendingVoucher else { return }
        voucher.isRedeemed = true
        voucher.redeemedAt = Date()
        appendVoucherHistory(voucher)
        persistence.saveVoucherHistory(voucherHistory)
        updateStressPoints(CatStressConstants.stressAfterVoucherClaim)
        lastVoucherGeneratedDate = Date()
        persistence.saveLastVoucherDate(lastVoucherGeneratedDate)
        withAnimation(.easeOut(duration: 0.3)) {
            self.setIsVoucherOverlayVisible(false)
        }
        setPendingVoucher(nil)
//        cancelPendingAnimations()
//        processEvent(.voucherClaimed)
    }

    func dismissVoucherOverlay() {
        withAnimation(.easeOut(duration: 0.3)) {
            self.setIsVoucherOverlayVisible(false)
        }
        setPendingVoucher(nil)
    }

    func togglePassport() {
        withAnimation(.spring(
            response: CatAnimationConstants.springResponse,
            dampingFraction: Double(CatAnimationConstants.springDamping)
        )) {
            self.setIsPassportVisible(!isPassportVisible)
        }
    }

    func handleCatTapped() {
        if showVoucherEnvelope {
            CatAudioManager.shared.play(.tapVoucher)
            handleVoucherTapped()
        } else {
            CatAudioManager.shared.play(.tapMeow)
            togglePassport()
        }
    }

    // MARK: - Drag to Dismiss

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
        } else {
            withAnimation(nil) {
                self.dragOffsetX = 0
                self.dragOffsetY = 0
            }
            startIdleTimer()
        }
    }

    func isNearScreenEdge(posX: CGFloat, posY: CGFloat) -> Bool {
        let threshold: CGFloat = 20
        return posX < threshold
            || posX > screenWidth - threshold
            || posY < threshold
            || posY > screenHeight - threshold
    }

    // MARK: - Dismiss / Bring Back

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

    func bringBack() {
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
