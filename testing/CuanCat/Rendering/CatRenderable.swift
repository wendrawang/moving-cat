import SwiftUI

// MARK: - Cat Renderable Protocol

/// Protocol untuk cat rendering. Diimplementasi oleh LottieCatRenderer (aktif),
/// USDCCatRenderer, dan CatVideoRenderer (keduanya legacy).
protocol CatRenderable {

    associatedtype Body: View

    func makeBody(
        state: CatState,
        direction: CatDirection,
        onFirstFrameReady: (() -> Void)?
    ) -> Body
}
