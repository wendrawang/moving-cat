import Combine
import SwiftUI
import UIKit

// MARK: - Cat Overlay Manager

/// Singleton facade untuk Tamagotchi cat system.
///
/// Integration guide:
/// ```
/// CatOverlayManager.shared.show()
/// CatOverlayManager.shared.startLoading()
/// CatOverlayManager.shared.stopLoading()
/// CatOverlayManager.shared.transactionSuccess()
/// CatOverlayManager.shared.transactionFailed()
/// ```
final class CatOverlayManager {

    // MARK: - Singleton

    static let shared = CatOverlayManager()

    // MARK: - Internal Components

    var overlayWindow: PassThroughWindow?
    var hostingController: ShakeDetectingHostingController<CatContainerView>?
    private(set) var engine: CatBehaviorEngine?

    // MARK: - State

    private(set) var isVisible: Bool = false

    private init() {}

    // MARK: - Prepare (panggil dari AppDelegate sebelum show)

    /// Parse + build semua Lottie layer di background/main-staggered.
    /// Panggil di AppDelegate.didFinishLaunching agar selesai sebelum show() dipanggil.
    func prepare() {
//        LottieCatRenderer.prebuildAll()
        CatAnimationCache.shared.preloadEager()
        CatAudioManager.shared.prepare()
    }

    // MARK: - Show / Hide

    func show() {
        guard !isVisible else { return }
        // Tunggu prebuild selesai sebelum attach ke window.
        // Kalau prepare() tidak dipanggil, group count = 0 → langsung masuk actualShow().
//        LottieCatRenderer.prebuildGroup.notify(queue: .main) { [weak self] in
//            self?.actualShow()
//        }
        actualShow()
    }

    private func actualShow() {
        guard !isVisible else { return }
        let behaviorEngine = CatBehaviorEngine()
        self.engine = behaviorEngine

        let containerView = CatContainerView(engine: behaviorEngine)
        let hosting = ShakeDetectingHostingController(rootView: containerView)
        hosting.view.backgroundColor = .clear
        hosting.onShake = { [weak behaviorEngine] in
            behaviorEngine?.bringBack()
        }

        let window = PassThroughWindow(frame: UIScreen.main.bounds)

        if let activeScene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive })
            ?? UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first {
            window.windowScene = activeScene
        }

        window.rootViewController = hosting
        window.windowLevel = UIWindow.Level(
            rawValue: CGFloat(CatLayoutConstants.overlayWindowLevel)
        )
        window.backgroundColor = .clear
        window.isOpaque = false
        window.isHidden = false

        window.interactiveRectProvider = { [weak behaviorEngine] in
            guard let eng = behaviorEngine, !eng.isDismissed else { return .zero }
            let halfSize = CatLayoutConstants.avatarSize / 2
            return CGRect(
                x: eng.currentVisualX - halfSize,
                y: eng.catPositionY - halfSize,
                width: CatLayoutConstants.avatarSize,
                height: CatLayoutConstants.avatarSize
            )
        }

        window.isModalVisibleProvider = { [weak behaviorEngine] in
            let passport = behaviorEngine?.isPassportVisible ?? false
            let voucher = behaviorEngine?.isVoucherOverlayVisible ?? false
            return passport || voucher
        }

        window.alphaHitTestView = hosting.view
        self.overlayWindow = window
        self.hostingController = hosting
        self.isVisible = true

        window.makeKey()
        hosting.becomeFirstResponder()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            let appWindows = UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap { $0.windows }
            appWindows.first(where: { $0 !== window && !$0.isHidden })?.makeKey()
            hosting.becomeFirstResponder()
        }
    }

    func hide() {
        engine?.cleanup()
        engine = nil
        overlayWindow?.isHidden = true
        overlayWindow = nil
        hostingController = nil
        isVisible = false
        pendingTracked = false
    }

    // MARK: - Loading API

    private var pendingTracked: Bool = false

    /// One-shot flag — aktifkan exhausted animation untuk 1x `startLoading()` berikutnya.
    func trackNextLoading() {
        pendingTracked = true
    }

    func startLoading() {
        let type: CatLoadingType = pendingTracked ? .tracked : .silent
        pendingTracked = false
        engine?.handleLoadingStarted(type)
    }

    func stopLoading() {
        engine?.handleLoadingStopped()
    }

    // MARK: - Transaction API

    func transactionSuccess() {
        engine?.handleTransactionSuccess()
    }

    func transactionFailed() {
        engine?.handleTransactionFailed()
    }

    func reportError(_ errorType: CatTransactionError) {
        engine?.handleTransactionError(errorType)
    }

    // MARK: - Walking Control

    func setWalkingEnabled(_ enabled: Bool) {
        engine?.setWalkingEnabled(enabled)
    }

    // MARK: - Passport

    func showPassport() {
        engine?.togglePassport()
    }

    // MARK: - Dismiss / Bring Back

    func dismiss() {
        engine?.dismiss()
    }

    func bringBack() {
        engine?.bringBack()
    }
}
