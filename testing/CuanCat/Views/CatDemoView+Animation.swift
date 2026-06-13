import SwiftUI

// MARK: - Animation & Force State Section

extension CatDemoView {

    var animationSection: some View {
        DemoSection(title: "Force Animation") {
            VStack(spacing: 8) {
                // idle & walking disembunyikan dari demo — state legacy yang
                // tidak muncul lagi (tapi tetap ada di kode untuk masa depan)
                let demoStates = CatState.allCases.filter { state in
                    state != .walking && state != .idle
                }
                ForEach(demoStates, id: \.self) { state in
                    let isDisabled = forceAnimationDisabled(state)
                    let isActive   = engine.currentState == state

                    Button(action: {
                        self.forceState(state)
                    }) {
                        DemoButtonLabel(
                            text: state.forceButtonName,
                            icon: nil,
                            color: isDisabled ? .secondary
                                : .primary
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                    .disabled(isDisabled)
                }
            }
        }
    }

    /// Aturan disable Force Animation per state:
    /// - rest (idle/warmup/pushup/starJump) : disabled saat walking — SwiftUI
    ///   withAnimation(.linear) tidak bisa di-cancel reliably → visual bug
    /// - walking   : selalu disabled — pos+anim timing bug saat force
    /// - happy     : hanya dari rest — butuh base state bersih agar timer berjalan benar
    /// - annoyed   : sama seperti happy
    /// - exhausted : sama seperti happy
    func forceAnimationDisabled(_ state: CatState) -> Bool {
        switch state {
        case .idle, .warmup, .pushup, .starJump:
            return engine.currentState == .walking
        case .walking:
            return true
        case .happy, .annoyed, .sad, .exhausted:
            return !engine.currentState.isRestState
        }
    }

    var forceAnimationHint: some View {
        let hint: String
        switch engine.currentState {
        case .idle, .warmup, .pushup, .starJump:
            hint = "Dari rest: happy / annoyed / sad / exhausted tersedia"
        case .walking:
            hint = "Sedang walking — tunggu selesai, rest & reaksi diblokir"
        case .happy, .annoyed, .sad, .exhausted:
            hint = "Animasi reaksi aktif — tunggu auto-return ke rest (3 detik)"
        }
        return Text(hint)
            .font(.caption)
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
