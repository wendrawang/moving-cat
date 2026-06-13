import SwiftUI

// MARK: - Cat Avatar View

struct CatAvatarView: View {

    let currentState: CatState
    let walkDirection: CatDirection
    let showVoucherEnvelope: Bool
    let onVoucherTap: () -> Void
    var onFirstFrameReady: (() -> Void)? = nil

    private let renderer = CatFrameRenderer()
//    private let renderer = LottieCatRenderer()
//    private let renderer = USDCCatRenderer()  // alternatif SceneKit (.usdc)
//    private let renderer = CatVideoRenderer()  // alternatif AVFoundation (.mov)

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
            state: currentState,
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
        lhs.currentState == rhs.currentState &&
        lhs.walkDirection == rhs.walkDirection &&
        lhs.showVoucherEnvelope == rhs.showVoucherEnvelope
    }
}
