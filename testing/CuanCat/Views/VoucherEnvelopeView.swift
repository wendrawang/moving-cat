import SwiftUI

// MARK: - Voucher Envelope Badge

/// Floating envelope badge that bounces near the cat.
/// Tapping it opens the voucher claim overlay.
struct VoucherEnvelopeView: View {

    let onTap: () -> Void

    @State private var bounceToggle: Bool = false

    var body: some View {
        Button(action: onTap) {
            ZStack {
                Text("\u{1F48C}")
                    .font(.system(size: CatLayoutConstants.envelopeBadgeSize))

                Circle()
                    .fill(Color.red)
                    .frame(width: 10, height: 10)
                    .offset(x: 10, y: -10)
            }
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(bounceToggle ? 1.1 : 0.9)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                withAnimation(
                    Animation.easeInOut(duration: 0.6)
                        .repeatForever(autoreverses: true)
                ) {
                    self.bounceToggle = true
                }
            }
        }
    }
}

// MARK: - Voucher Claim Overlay

/// Full-screen overlay that appears when user taps the envelope badge.
/// Shows an animated golden ticket with voucher code + confetti effect.
struct VoucherClaimOverlay: View {

    let voucher: VoucherModel
    let onClaim: () -> Void
    var onDismiss: (() -> Void)?

    @State private var envelopePhase: Int = 0
    @State private var confettiTrigger: Bool = false
    @State private var ticketOffset: CGFloat = 200

    var body: some View {
        ZStack {
            Color.black.opacity(envelopePhase > 0 ? 0.55 : 0.0)
                .edgesIgnoringSafeArea(.all)
                .onTapGesture { self.onDismiss?() }

            VStack {
                HStack {
                    Spacer()
                    Button(action: { self.onDismiss?() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .buttonStyle(PlainButtonStyle())
                    .padding(20)
                }
                Spacer()
            }

            if confettiTrigger {
                ConfettiView()
            }

            VStack(spacing: 0) {
                Spacer()
                envelopeAndTicket
                Spacer()
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                envelopePhase = 1
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.65)) {
                    envelopePhase = 2
                    ticketOffset = 0
                }
                confettiTrigger = true
            }
        }
    }

    private var envelopeAndTicket: some View {
        ZStack {
            EnvelopeBodyView(phase: envelopePhase)
                .scaleEffect(envelopePhase >= 1 ? 1.0 : 0.3)
                .opacity(envelopePhase >= 1 ? 1.0 : 0.0)
                .offset(y: envelopePhase >= 2 ? 80 : 0)

            if envelopePhase >= 2 {
                GoldenTicketView(voucher: voucher, onClaim: onClaim)
                    .offset(y: ticketOffset)
            }
        }
    }
}
