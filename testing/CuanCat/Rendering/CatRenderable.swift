import SwiftUI

// MARK: - Cat Renderable Protocol

/// Protocol untuk cat rendering. Diimplementasi oleh CatFrameRenderer (aktif).
/// Renderer menerima CatAnimationType langsung (bukan CatState) karena satu
/// state bisa punya beberapa variant animasi (idle → warmup/pushup/starJump).
protocol CatRenderable {

    associatedtype Body: View

    func makeBody(
        animation: CatAnimationType,
        direction: CatDirection,
        onFirstFrameReady: (() -> Void)?
    ) -> Body
}
