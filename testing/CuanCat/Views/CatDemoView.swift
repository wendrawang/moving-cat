import SwiftUI
import UIKit

// MARK: - Cat Demo View
//
// Panel kontrol untuk demo di acara kantor.
// Bisa diakses via CatOverlayManager.shared.showDemo()

struct CatDemoView: View {

    @ObservedObject var engine: CatBehaviorEngine

    @State var stressSlider: Double = 0
    @State private var willTrackNextLoading: Bool = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
//                    stressControlSection
                    animationSection
//                    catControlSection
                    voucherSection
                }
                .padding(20)
            }
            .navigationBarTitle("Cat Demo Panel", displayMode: .inline)
        }
        .onAppear {
            stressSlider = Double(engine.stressPoints)
        }
    }

    // MARK: - Stress Control

    var stressControlSection: some View {
        DemoSection(title: "Stress Control") {
            VStack(spacing: 12) {
                HStack {
                    Text("Stress: \(Int(stressSlider))")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Spacer()
                    stressTierBadge
                }

                Slider(value: $stressSlider, in: 0...100, step: 1)

                Button(action: {
                    engine.updateStressPoints(Int(stressSlider))
                }) {
                    DemoButtonLabel(text: "Apply Stress", color: .orange)
                }

                HStack(spacing: 12) {
                    Button(action: {
                        stressSlider = 0
                        engine.updateStressPoints(0)
                    }) {
                        DemoButtonLabel(text: "Reset 0", color: .green)
                    }

                    Button(action: {
                        stressSlider = 50
                        engine.updateStressPoints(50)
                    }) {
                        DemoButtonLabel(text: "Set 50", color: .yellow)
                    }

                    Button(action: {
                        stressSlider = Double(CatStressConstants.voucherStressThreshold)
                        engine.updateStressPoints(CatStressConstants.voucherStressThreshold)
                    }) {
                        DemoButtonLabel(text: "Set \(CatStressConstants.voucherStressThreshold)", color: .red)
                    }

                    Button(action: {
                        stressSlider = 100
                        engine.updateStressPoints(100)
                    }) {
                        DemoButtonLabel(text: "Max", color: .red)
                    }
                }
            }
        }
    }

    var stressTierBadge: some View {
        let tier: String
        let color: Color
        let val = Int(stressSlider)
        switch val {
        case 0...30:
            tier = "Sehat"
            color = .green
        case 31...60:
            tier = "Waspada"
            color = .yellow
        case 61...(CatStressConstants.gatewayTimeoutVoucherThreshold - 1):
            tier = "Kritis"
            color = .orange
        case CatStressConstants.gatewayTimeoutVoucherThreshold...(CatStressConstants.voucherStressThreshold - 1):
            tier = "Voucher (504)"
            color = Color(red: 1.0, green: 0.4, blue: 0.0)
        default:
            tier = "Voucher!"
            color = .red
        }
        return Text(tier)
            .font(.system(size: 11, weight: .bold))
            .foregroundColor(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(color.opacity(0.15))
            )
    }

    // MARK: - Helpers

    func forceState(_ state: CatState) {
        engine.stopIdleTimer()
        engine.stopLoadingTimer()
        engine.stopWalkTimer()
        engine.cancelPendingAnimations()
        engine.forceState(state)
    }

    func resetToCenter() {
        let bounds = UIScreen.main.bounds
        engine.homePositionX = bounds.width * CatLayoutConstants.defaultStartXRatio
        engine.homePositionY = bounds.height - CatLayoutConstants.bottomPadding
        engine.setCatPositionX(engine.homePositionX)
        engine.setCatPositionY(engine.homePositionY)
    }
}
