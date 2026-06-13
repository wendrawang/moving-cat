import SwiftUI

// MARK: - Cat Container View

/// Root SwiftUI container — positions cat on screen, overlay-level layout.
struct CatContainerView: View {

    @ObservedObject var engine: CatBehaviorEngine

    var body: some View {
        ZStack {
            catLayer
            passportLayer
            voucherOverlayLayer
        }
        .edgesIgnoringSafeArea(.all)
    }

    // MARK: - Cat Layer

    private var catLayer: some View {
        GeometryReader { _ in
            CatAvatarView(
                currentState: self.engine.currentState,
                walkDirection: self.engine.walkDirection,
                showVoucherEnvelope: self.engine.showVoucherEnvelope,
                onVoucherTap: { self.engine.handleVoucherTapped() },
                onFirstFrameReady: { self.engine.markReadyAndStartTimer() }
            )
            .equatable()
            .frame(
                width: CatLayoutConstants.avatarSize,
                height: CatLayoutConstants.avatarSize
            )
            .contentShape(Rectangle())
            .offset(
                x: self.engine.dragOffsetX,
                y: self.engine.dragOffsetY
            )
            .gesture(self.catGesture)
            .opacity(self.engine.isDismissed ? 0 : 1)
            .position(
                x: self.engine.catPositionX,
                y: self.engine.catPositionY
            )
        }
    }

    // MARK: - Gesture (drag + tap detection)
    // Tap dan drag dalam 1 DragGesture — menghindari konflik gesture.
    // Tap = translation < 10pt.

    private var catGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                let dist = sqrt(
                    value.translation.width * value.translation.width
                    + value.translation.height * value.translation.height
                )
                // Hanya mulai drag offset setelah jarak cukup (bukan tap)
                if dist > 10 {
                    self.engine.handleDragChanged(translation: value.translation)
                }
            }
            .onEnded { value in
                let dist = sqrt(
                    value.translation.width * value.translation.width
                    + value.translation.height * value.translation.height
                )
                if dist <= 10 {
                    // Tap → buka passport atau voucher tergantung stress
                    self.engine.handleCatTapped()
                } else {
                    // Drag → cek dismiss
                    self.engine.handleDragEnded(translation: value.translation)
                }
            }
    }

    // MARK: - Passport Layer (iOS 13 compatible)

    private var passportLayer: some View {
        Group {
            if engine.isPassportVisible {
                ZStack {
                    Color.black.opacity(0.4)
                        .edgesIgnoringSafeArea(.all)
                        .onTapGesture {
                            self.engine.togglePassport()
                        }

                    CatPassportView(
                        stressPoints: self.engine.stressPoints,
                        voucherHistory: self.engine.voucherHistory,
                        onDismiss: {
                            self.engine.togglePassport()
                        }
                    )
                    .transition(.move(edge: .bottom))
                }
            }
        }
    }

    // MARK: - Voucher Overlay Layer (iOS 13 compatible)

    private var voucherOverlayLayer: some View {
        VoucherOverlayWrapper(engine: engine)
    }
}

// MARK: - Voucher Overlay Wrapper

private struct VoucherOverlayWrapper: View {

    @ObservedObject var engine: CatBehaviorEngine

    var body: some View {
        // RF-08 fix: gunakan pendingVoucher langsung sebagai source of truth.
        // Sebelumnya fallback ke VoucherModel(voucherType: .apology) yang
        // membuat throwaway object dengan UUID/kode acak setiap re-render.
        Group {
            if engine.isVoucherOverlayVisible, let voucher = engine.pendingVoucher {
                VoucherClaimOverlay(
                    voucher: voucher,
                    onClaim: { engine.handleVoucherClaim() },
                    onDismiss: { engine.dismissVoucherOverlay() }
                )
                .transition(.opacity)
            }
        }
    }
}
