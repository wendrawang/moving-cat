import SwiftUI

// MARK: - Animation & Force State Section

extension CatDemoView {

    var animationSection: some View {
        DemoSection(title: "Force Animation") {
            VStack(spacing: 8) {
                let allStateWithoutWalk = CatState.allCases.filter({ $0 != .walking })
                ForEach(allStateWithoutWalk, id: \.self) { state in
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
    /// - idle      : disabled saat walking — SwiftUI withAnimation(.linear) tidak bisa
    ///               di-cancel reliably, posisi lanjut ke walkTargetX → visual bug
    /// - walking   : selalu disabled — pos+anim timing bug saat force
    /// - happy     : hanya dari idle — butuh base state bersih agar timer berjalan benar
    /// - annoyed   : sama seperti happy
    /// - exhausted : selalu aktif — demo purposes: tampilkan animasi ke customer,
    ///               exit via force idle setelah selesai
    func forceAnimationDisabled(_ state: CatState) -> Bool {
        switch state {
        case .idle:               return engine.currentState == .walking
        case .walking:            return true
        case .happy:              return engine.currentState != .idle
        case .annoyed, .sad:      return engine.currentState != .idle
        case .exhausted:          return engine.currentState != .idle
        }
    }

    var forceAnimationHint: some View {
        let hint: String
        switch engine.currentState {
        case .idle:
            hint = "Dari idle: happy / annoyed / sad / exhausted tersedia"
        case .walking:
            hint = "Sedang walking — tunggu selesai, idle & reaksi diblokir"
        case .happy, .annoyed, .sad, .exhausted:
            hint = "Animasi reaksi aktif — tunggu auto-return ke idle (3 detik)"
        }
        return Text(hint)
            .font(.caption)
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
