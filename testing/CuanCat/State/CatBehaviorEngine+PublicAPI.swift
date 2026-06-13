import Foundation
import SwiftUI
import UIKit

// MARK: - Transaction & Voucher Public API

extension CatBehaviorEngine {

    // MARK: - Transaction

    func handleTransactionSuccess() {
        processEvent(.transactionSuccess)
    }

    /// transactionFailed() dari public API → selalu animasi sad.
    func handleTransactionFailed() {
        applyStressDelta(CatStressConstants.transactionFailedIncrease)
        processEvent(.transactionFailedSad)
    }

    /// reportError(_:) dari public API → selalu animasi annoyed (transactionFailed).
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
        processEvent(.transactionFailed)
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

}
