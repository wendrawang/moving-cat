import SwiftUI
import UIKit

// MARK: - Demo

extension CatOverlayManager {

    /// Tampilkan demo panel sebagai sheet.
    /// Prioritas: presenter yang diberikan → main app window → overlay window.
    /// Bisa juga langsung embed `CatDemoView(engine: engine)` di app.
    func showDemo(from viewController: UIViewController? = nil) {
        guard let eng = engine else { return }
        let demoView = CatDemoView(engine: eng)
        let hosting = UIHostingController(rootView: demoView)
        hosting.modalPresentationStyle = .pageSheet

        let mainAppVC = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first(where: { $0 !== overlayWindow && !$0.isHidden })?
            .rootViewController

        let presenter = viewController ?? mainAppVC ?? hostingController

        var top = presenter
        while let presented = top?.presentedViewController {
            top = presented
        }
        top?.present(hosting, animated: true)
    }
}
