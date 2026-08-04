import SwiftUI

// MARK: - Cat Container View

/// Root SwiftUI container — positions cat on screen, overlay-level layout.
struct CatContainerView: View {

    @ObservedObject var engine: CatBehaviorEngine

    var body: some View {
        ZStack {
            spotlightScrimLayer
            spotlightHaloLayer
            spotlightBeamLayer
            spotlightParticlesLayer
            catLayer
            spotlightStageLabelLayer
            passportLayer
            voucherOverlayLayer
        }
        .edgesIgnoringSafeArea(.all)
    }

    // MARK: - Spotlight Scrim Layer
    // Gelapkan seluruh layar saat kucing tampil supaya sorot lampu kelihatan
    // walau UI app terang. Tidak menangkap touch (hit test diatur window).

    private var spotlightScrimLayer: some View {
        Color.black
            .opacity(
                self.engine.isSpotlightPresent
                    ? Double(CatLayoutConstants.spotlightScrimOpacity)
                    : 0
            )
            .edgesIgnoringSafeArea(.all)
            .allowsHitTesting(false)
    }

    // MARK: - Spotlight Halo Layer
    // Cahaya lembut di sekitar kucing yang menembus scrim gelap.

    private var spotlightHaloLayer: some View {
        Circle()
            .fill(
                RadialGradient(
                    gradient: Gradient(colors: [
                        Color.white.opacity(0.28),
                        Color.white.opacity(0.0)
                    ]),
                    center: .center,
                    startRadius: 0,
                    endRadius: CatLayoutConstants.spotlightHaloDiameter / 2
                )
            )
            .frame(
                width: CatLayoutConstants.spotlightHaloDiameter,
                height: CatLayoutConstants.spotlightHaloDiameter
            )
            .opacity(self.engine.isSpotlightPresent ? 1 : 0)
            .position(
                x: self.engine.spotlightX,
                y: self.engine.spotlightY + CatLayoutConstants.spotlightHaloOffsetY
            )
            .allowsHitTesting(false)
    }

    // MARK: - Spotlight Beam Layer
    // Sorot lampu di belakang kucing — muncul/hilang mengikuti presence.

    private var spotlightBeamLayer: some View {
        SpotlightBeamView()
            .opacity(self.engine.isSpotlightPresent ? 1 : 0)
            .position(
                x: self.engine.spotlightX,
                y: self.engine.spotlightY
                    - CatLayoutConstants.spotlightBeamHeight / 2
                    + CatLayoutConstants.avatarSize * 0.5
                    + CatLayoutConstants.spotlightHaloOffsetY
            )
            .allowsHitTesting(false)
    }

    // MARK: - Spotlight Particles Layer
    // Debu cahaya melayang di dalam beam — biar panggung tidak sepi.

    private var spotlightParticlesLayer: some View {
        SpotlightParticlesView()
            .opacity(self.engine.isSpotlightPresent ? 1 : 0)
            .position(
                x: self.engine.spotlightX,
                y: self.engine.spotlightY
                    - CatLayoutConstants.spotlightBeamHeight / 2
                    + CatLayoutConstants.avatarSize * 0.5
                    + CatLayoutConstants.spotlightHaloOffsetY
            )
            .allowsHitTesting(false)
    }

    // MARK: - Spotlight Stage Label Layer
    // "NOW PERFORMING / CuanCat" — hanya saat kemunculan AFK, auto-hilang.

    private var spotlightStageLabelLayer: some View {
        VStack(spacing: 2) {
            Text(CatStrings.stagePerformingCaption)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundColor(Color.white.opacity(0.7))
            Text(CatStrings.stageName)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(.white)
        }
        .shadow(color: Color.black.opacity(0.5), radius: 4, x: 0, y: 1)
        .opacity(self.engine.isStageLabelVisible ? 1 : 0)
        .position(
            x: self.engine.spotlightX,
            y: self.engine.spotlightY + CatLayoutConstants.avatarSize * 0.5 + 22
        )
        .allowsHitTesting(false)
    }

    // MARK: - Cat Layer

    private var catLayer: some View {
        GeometryReader { _ in
            CatAvatarView(
                displayAnimation: self.engine.displayAnimation,
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
            .opacity(
                (self.engine.isDismissed || !self.engine.isSpotlightPresent)
                    ? 0 : 1
            )
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
