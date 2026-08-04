import SwiftUI

// MARK: - Cat Avatar View

struct CatAvatarView: View {

    /// Animasi yang dirender — engine yang menentukan (state idle bisa
    /// menjadi warmup/pushup/starJump via CatBehaviorEngine.displayAnimation).
    let displayAnimation: CatAnimationType
    let walkDirection: CatDirection
    let showVoucherEnvelope: Bool
    let onVoucherTap: () -> Void
    var onFirstFrameReady: (() -> Void)? = nil

    private let renderer = CatFrameRenderer()

    var body: some View {
        ZStack {
            renderedCat
            voucherBadge
        }
        .frame(
            width: CatLayoutConstants.avatarSize,
            height: CatLayoutConstants.avatarSize
        )
        .contentShape(Rectangle())
    }

    // MARK: - Rendered Cat

    private var renderedCat: some View {
        renderer.makeBody(
            animation: displayAnimation,
            direction: walkDirection,
            onFirstFrameReady: onFirstFrameReady
        )
    }

    // MARK: - Voucher Badge (iOS 13 compatible)

    private var voucherBadge: some View {
        Group {
            if showVoucherEnvelope {
                VoucherEnvelopeView(onTap: onVoucherTap)
                    .offset(
                        x: CatLayoutConstants.avatarSize * 0.18,
                        y: CatLayoutConstants.speechBubbleOffsetY * 0.9
                    )
            }
        }
    }
}

// MARK: - Equatable

extension CatAvatarView: Equatable {
    static func == (lhs: CatAvatarView, rhs: CatAvatarView) -> Bool {
        lhs.displayAnimation == rhs.displayAnimation &&
        lhs.walkDirection == rhs.walkDirection &&
        lhs.showVoucherEnvelope == rhs.showVoucherEnvelope
    }
}
