import SwiftUI
import UIKit

// MARK: - Pass-Through Window

final class PassThroughWindow: UIWindow {

    var interactiveRectProvider: (() -> CGRect)?
    var isModalVisibleProvider: (() -> Bool)?
    /// Set ke hosting.view — dipakai untuk alpha hit test pixel-level.
    weak var alphaHitTestView: UIView?

    override var canBecomeFirstResponder: Bool { true }

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard let hitView = super.hitTest(point, with: event) else {
            return nil
        }

        if rootViewController?.presentedViewController != nil {
            return hitView
        }

        if let isModal = isModalVisibleProvider, isModal() {
            return hitView
        }

        guard let rectProvider = interactiveRectProvider else {
            return nil
        }
        let catRect = rectProvider()
        guard catRect.contains(point) else {
            return nil
        }

        // Pixel-level alpha check: jika titik touch transparan di Lottie animation,
        // lewatkan touch ke app di bawah. Dipanggil 1x per gesture (saat touch began).
        if let view = alphaHitTestView, isTransparentPixel(at: point, in: view) {
            return nil
        }

        return hitView
    }

    /// Render 1×1 pixel dari view di koordinat `point`, kemudian cek alpha channel-nya.
    /// Menggunakan `layer.render` yang berjalan di main thread — aman karena
    /// `hitTest` selalu dipanggil dari main thread.
    private static let deviceRGB = CGColorSpaceCreateDeviceRGB()

    private func isTransparentPixel(at point: CGPoint, in view: UIView) -> Bool {
        var pixel: [UInt8] = [0, 0, 0, 0]
        let rendered = pixel.withUnsafeMutableBytes { ptr -> Bool in
            guard let context = CGContext(
                data: ptr.baseAddress,
                width: 1,
                height: 1,
                bitsPerComponent: 8,
                bytesPerRow: 4,
                space: PassThroughWindow.deviceRGB,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { return false }
            // Geser canvas sehingga `point` jatuh tepat di pixel (0,0)
            context.translateBy(x: -point.x, y: -point.y)
            view.layer.render(in: context)
            return true
        }
        guard rendered else { return false }
        // Alpha < 10 (~4%) dianggap transparan
        return pixel[3] < 10
    }

    deinit {
        interactiveRectProvider = nil
        isModalVisibleProvider = nil
    }
}

// MARK: - Shake Detecting Hosting Controller

final class ShakeDetectingHostingController<Content: View>:
    UIHostingController<Content> {

    var onShake: (() -> Void)?

    override var canBecomeFirstResponder: Bool { true }

    override func motionEnded(
        _ motion: UIEvent.EventSubtype,
        with event: UIEvent?
    ) {
        if motion == .motionShake {
            onShake?()
        }
        super.motionEnded(motion, with: event)
    }
}
