import SwiftUI

// MARK: - Cat Control & Voucher Sections

extension CatDemoView {

    var catControlSection: some View {
        DemoSection(title: "Cat Control") {
            VStack(spacing: 12) {
                walkingToggleRow

                HStack(spacing: 12) {
                    Button(action: { engine.dismiss() }) {
                        DemoButtonLabel(
                            text: "Dismiss",
                            icon: "arrow.down.right.and.arrow.up.left",
                            color: .orange
                        )
                    }

                    Button(action: { engine.bringBack() }) {
                        DemoButtonLabel(
                            text: "Bring Back",
                            icon: "arrow.uturn.left",
                            color: .blue
                        )
                    }
                }

                HStack(spacing: 12) {
                    Button(action: { engine.togglePassport() }) {
                        DemoButtonLabel(
                            text: "Stress Level",
                            icon: "person.crop.rectangle",
                            color: .purple
                        )
                    }

                    Button(action: { resetToCenter() }) {
                        DemoButtonLabel(
                            text: "Reset Pos",
                            icon: "arrow.counterclockwise",
                            color: .gray
                        )
                    }
                }
            }
        }
    }

    private var walkingToggleRow: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Walking")
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(engine.isWalkingEnabled
                     ? "Aktif — kucing jalan di idle"
                     : "Nonaktif — kucing diam (selesaikan langkah dulu)")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            Spacer()
            Button(action: {
                engine.setWalkingEnabled(!engine.isWalkingEnabled)
            }) {
                Text(engine.isWalkingEnabled ? "Disable" : "Enable")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(engine.isWalkingEnabled ? Color.orange : Color.green)
                    )
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.gray.opacity(0.06))
        )
    }

    var voucherSection: some View {
        DemoSection(title: "Voucher") {
            VStack(spacing: 12) {
                Button(action: {
                    engine.updateStressPoints(CatStressConstants.voucherStressThreshold)
                    stressSlider = Double(CatStressConstants.voucherStressThreshold)
                    engine.setShowVoucherEnvelope(true)
                }) {
                    DemoButtonLabel(
                        text: "Simulasi Saat Mencapai Stress Level Maximum",
                        icon: "envelope.fill",
                        color: engine.currentState != .idle
                            ? .secondary
                            : .orange
                    )
                }
                .disabled(engine.currentState != .idle)
            }
        }
    }
}
