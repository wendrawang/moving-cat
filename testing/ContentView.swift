import SwiftUI

struct ContentView: View {

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    lifecycleSection
                    loadingSection
                    transactionSection
                    errorSection
                    uiSection
                }
                .padding(16)
            }
            .navigationBarTitle("CuanCat Demo", displayMode: .inline)
        }
        .onAppear {
            // Walking TIDAK diaktifkan lagi — dikunci via CatFeatureFlags.autoWalkingEnabled
            CatOverlayManager.shared.show()
        }
    }

    // MARK: - Lifecycle

    private var lifecycleSection: some View {
        ControlSection(title: "Lifecycle") {
            HStack(spacing: 12) {
                ControlButton(label: "show()", color: .green) {
                    CatOverlayManager.shared.show()
                }
                ControlButton(label: "hide()", color: .red) {
                    CatOverlayManager.shared.hide()
                }
            }
        }
    }

    // MARK: - Loading

    private var loadingSection: some View {
        ControlSection(title: "Loading") {
            VStack(spacing: 10) {
                HStack(spacing: 12) {
                    ControlButton(label: "startLoading()\n.silent", color: .purple) {
                        CatOverlayManager.shared.startLoading()
                    }
                    ControlButton(label: "stopLoading()", color: .gray) {
                        CatOverlayManager.shared.stopLoading()
                    }
                }
                ControlButton(
                    label: "trackNextLoading() + startLoading()",
                    color: .blue
                ) {
                    CatOverlayManager.shared.trackNextLoading()
                    CatOverlayManager.shared.startLoading()
                }
                Text("trackNextLoading() → exhausted muncul jika loading > 10 detik")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    // MARK: - Transaction

    private var transactionSection: some View {
        ControlSection(title: "Transaction") {
            HStack(spacing: 12) {
                ControlButton(
                    label: "transactionSuccess()\nstress −15",
                    color: .green
                ) {
                    CatOverlayManager.shared.transactionSuccess()
                }
                ControlButton(
                    label: "transactionFailed()\nstress +10",
                    color: .red
                ) {
                    CatOverlayManager.shared.transactionFailed()
                }
            }
        }
    }

    // MARK: - Error

    private var errorSection: some View {
        ControlSection(title: "reportError()") {
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    ControlButton(
                        label: ".gatewayTimeout\n+20 | voucher@75",
                        color: .red
                    ) {
                        CatOverlayManager.shared.reportError(.gatewayTimeout)
                    }
                    ControlButton(
                        label: ".serverError\n+15",
                        color: .orange
                    ) {
                        CatOverlayManager.shared.reportError(.serverError)
                    }
                }
                HStack(spacing: 8) {
                    ControlButton(
                        label: ".networkError\n+10",
                        color: Color(red: 0.8, green: 0.6, blue: 0.0)
                    ) {
                        CatOverlayManager.shared.reportError(.networkError)
                    }
                    ControlButton(
                        label: ".clientError\n+0 (annoy only)",
                        color: .gray
                    ) {
                        CatOverlayManager.shared.reportError(.clientError)
                    }
                }
                ControlButton(
                    label: ".unknown  +10",
                    color: Color(red: 0.5, green: 0.2, blue: 0.7)
                ) {
                    CatOverlayManager.shared.reportError(.unknown)
                }
            }
        }
    }

    // MARK: - UI

    private var uiSection: some View {
        ControlSection(title: "UI") {
            VStack(spacing: 10) {
                HStack(spacing: 12) {
                    ControlButton(label: "dismiss()", color: .orange) {
                        CatOverlayManager.shared.dismiss()
                    }
                    ControlButton(label: "bringBack()", color: .blue) {
                        CatOverlayManager.shared.bringBack()
                    }
                }
                HStack(spacing: 12) {
                    ControlButton(label: "showPassport()", color: .purple) {
                        CatOverlayManager.shared.showPassport()
                    }
                    ControlButton(label: "showDemo()", color: .purple) {
                        CatOverlayManager.shared.showDemo()
                    }
                }
            }
        }
    }
}

// MARK: - Control Section

private struct ControlSection<Content: View>: View {

    let title: String
    let content: () -> Content

    init(title: String, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.secondary)
            content()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(UIColor.secondarySystemBackground))
        )
    }
}

// MARK: - Control Button

private struct ControlButton: View {

    let label: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 12, weight: .semibold))
                .multilineTextAlignment(.center)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(color)
                )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    ContentView()
}
