import SwiftUI

// MARK: - Voucher Card

extension CatPassportView {

    func voucherCard(_ voucher: VoucherModel) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(voucher.voucherType.displayTitle)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Spacer()
                statusBadge(voucher)
            }

            HStack {
                Text(voucher.code)
                    .font(.system(.body, design: .monospaced))
                    .fontWeight(.bold)
                    .foregroundColor(
                        voucher.isExpired
                            ? Color.secondary
                            : Color(red: 0.70, green: 0.45, blue: 0.05)
                    )
                Spacer()
                copyButton(voucher)
            }

            HStack(spacing: 16) {
                dateLabel(
                    icon: "calendar",
                    text: "Dibuat: \(formatShortDate(voucher.createdAt))"
                )
                dateLabel(
                    icon: "clock",
                    text: "Exp: \(formatShortDate(voucher.expiryDate))"
                )
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(cardBackground(voucher))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(cardBorderColor(voucher), lineWidth: 1)
        )
        .opacity(voucher.isExpired ? 0.7 : 1.0)
    }

    func statusBadge(_ voucher: VoucherModel) -> some View {
        Text(voucher.statusText)
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(statusColor(voucher))
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(statusColor(voucher).opacity(0.12))
            )
    }

    func copyButton(_ voucher: VoucherModel) -> some View {
        Button(action: {
            UIPasteboard.general.string = voucher.code
            self.copiedCode = voucher.code
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                if self.copiedCode == voucher.code {
                    self.copiedCode = nil
                }
            }
        }) {
            HStack(spacing: 4) {
                Image(systemName:
                    copiedCode == voucher.code ? "checkmark" : "doc.on.doc"
                )
                .font(.system(size: 12))

                Text(copiedCode == voucher.code ? "Copied!" : "Copy")
                    .font(.system(size: 12, weight: .medium))
            }
            .foregroundColor(copiedCode == voucher.code ? .green : .accentColor)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.accentColor.opacity(0.08))
            )
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(voucher.isExpired)
        .opacity(voucher.isExpired ? 0.5 : 1.0)
    }

    func dateLabel(icon: String, text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundColor(.secondary)
            Text(text)
                .font(.system(size: 10))
                .foregroundColor(.secondary)
        }
    }

    func cardBackground(_ voucher: VoucherModel) -> Color {
        if voucher.isExpired  { return Color.gray.opacity(0.05) }
        if voucher.isRedeemed { return Color.green.opacity(0.03) }
        return Color.orange.opacity(0.04)
    }

    func cardBorderColor(_ voucher: VoucherModel) -> Color {
        if voucher.isExpired  { return Color.gray.opacity(0.15) }
        if voucher.isRedeemed { return Color.green.opacity(0.15) }
        return Color.orange.opacity(0.2)
    }

    func statusColor(_ voucher: VoucherModel) -> Color {
        if voucher.isExpired  { return .red }
        if voucher.isRedeemed { return .green }
        return .orange
    }
}
