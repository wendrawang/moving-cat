import SwiftUI

// MARK: - Golden Ticket View

struct GoldenTicketView: View {

    let voucher: VoucherModel
    let onClaim: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            ticketHeader
            DashedDivider()
                .frame(height: 1)
                .padding(.horizontal, 16)
            voucherCodeDisplay
            ticketDescription
            claimButton
        }
        .padding(.vertical, 28)
        .padding(.horizontal, 20)
        .frame(width: 280)
        .background(ticketBackground)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    private var ticketHeader: some View {
        VStack(spacing: 6) {
            Text("\u{2728}  V O U C H E R  \u{2728}")
                .font(.system(size: 13, weight: .heavy))
                .foregroundColor(Color(red: 0.70, green: 0.50, blue: 0.10))

            Text(voucher.voucherType.displayTitle)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.primary)
                .multilineTextAlignment(.center)
        }
    }

    private var voucherCodeDisplay: some View {
        Text(voucher.code)
            .font(.system(size: 24, weight: .bold, design: .monospaced))
            .foregroundColor(Color(red: 0.70, green: 0.45, blue: 0.05))
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(
                        Color(red: 0.85, green: 0.65, blue: 0.20),
                        lineWidth: 2
                    )
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(red: 1.0, green: 0.97, blue: 0.88))
                    )
            )
    }

    private var ticketDescription: some View {
        Text(voucher.voucherType.displayDescription)
            .font(.system(size: 13))
            .foregroundColor(.secondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 20)
    }

    private var claimButton: some View {
        Button(action: onClaim) {
            HStack(spacing: 8) {
                Text("\u{1F381}")
                    .font(.system(size: 16))
                Text("Klaim Voucher")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 32)
            .padding(.vertical, 14)
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(red: 0.95, green: 0.60, blue: 0.10),
                        Color(red: 0.90, green: 0.45, blue: 0.05)
                    ]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 25))
            .shadow(color: Color.orange.opacity(0.4), radius: 8, y: 4)
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var ticketBackground: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(UIColor.systemBackground))
                .shadow(
                    color: Color(red: 0.85, green: 0.65, blue: 0.20).opacity(0.3),
                    radius: 16, y: 8
                )

            RoundedRectangle(cornerRadius: 20)
                .stroke(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color(red: 0.95, green: 0.80, blue: 0.40),
                            Color(red: 0.85, green: 0.60, blue: 0.15),
                            Color(red: 0.95, green: 0.80, blue: 0.40)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 3
                )
        }
    }
}
