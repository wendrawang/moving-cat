import SwiftUI

// MARK: - Cat Passport View (Detail Page)

struct CatPassportView: View {

    let stressPoints: Int
    let voucherHistory: [VoucherModel]
    let onDismiss: () -> Void

    @State var copiedCode: String?

    var body: some View {
        VStack(spacing: 0) {
            dragIndicator
            scrollContent
        }
        .frame(maxWidth: .infinity)
        .frame(height: UIScreen.main.bounds.height * 0.65)
        .background(
            RoundedRectangle(cornerRadius: CatLayoutConstants.passportCornerRadius)
                .fill(Color(UIColor.systemBackground))
        )
        .clipShape(
            RoundedRectangle(cornerRadius: CatLayoutConstants.passportCornerRadius)
        )
        .shadow(radius: 20)
        .padding(.top, UIScreen.main.bounds.height * 0.35)
    }

    // MARK: - Drag Indicator

    private var dragIndicator: some View {
        VStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 3)
                .fill(Color.gray.opacity(0.4))
                .frame(width: 40, height: 5)
                .padding(.top, 12)

            HStack {
                Text("Stress Level")
                    .font(.headline)
                    .fontWeight(.bold)

                Spacer()

                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.headline)
                        .foregroundColor(.gray)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 20)
        }
    }

    // MARK: - Scroll Content

    private var scrollContent: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(spacing: 24) {
                StressGaugeView(stressPoints: stressPoints)
                voucherHistorySection
            }
            .padding(20)
        }
    }

    // MARK: - Voucher History

    private var voucherHistorySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Voucher History")
                .font(.headline)
                .foregroundColor(.primary)

            if voucherHistory.isEmpty {
                emptyVoucherPlaceholder
            } else {
                ForEach(voucherHistory.reversed()) { voucher in
                    voucherCard(voucher)
                }
            }
        }
    }

    private var emptyVoucherPlaceholder: some View {
        VStack(spacing: 8) {
            Text("Belum ada voucher")
                .font(.subheadline)
                .foregroundColor(.secondary)
            Text("Voucher akan muncul saat stress kucing tinggi")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }

    // MARK: - Date Formatter

    static let shortDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd MMM yyyy"
        return formatter
    }()

    func formatShortDate(_ date: Date) -> String {
        CatPassportView.shortDateFormatter.string(from: date)
    }
}
