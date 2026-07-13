import CoreGraphics
import Foundation
import SwiftUI

// MARK: - Spotlight Positioning
//
// "Spotlight" = panggung tengah layar. Dua jalur menuju spotlight:
//   1. Rest states (warmup/pushup/starJump): jika TIDAK ada kegiatan apa pun
//      (idle >= idleToSpotlightThreshold, tanpa loading/drag/dismiss),
//      kucing glide halus ke tengah.
//   2. Reaction states (annoyed/sad/happy/exhausted): langsung tampil di
//      spotlight sejak muncul — snap instan, tanpa glide.
//
// Homebase ikut pindah ke spotlight sehingga sistem lain (walk, drag clamp,
// setHomeBase side effect) tetap konsisten.

extension CatBehaviorEngine {

    // MARK: - Spotlight Coordinates

    var spotlightX: CGFloat { screenWidth * CatLayoutConstants.spotlightXRatio }
    var spotlightY: CGFloat { screenHeight * CatLayoutConstants.spotlightYRatio }

    /// catPositionX/Y sudah bernilai target BEGITU withAnimation dimulai,
    /// jadi ini juga true selama glide berjalan — mencegah re-trigger per tick.
    var isAtSpotlight: Bool {
        abs(catPositionX - spotlightX) < 1.0
            && abs(catPositionY - spotlightY) < 1.0
    }

    // MARK: - Glide (rest state, tanpa kegiatan)

    /// Dipanggil setiap idle tick. Glide hanya saat benar-benar tidak ada
    /// kegiatan: rest state, tidak loading, tidak di-drag, tidak dismissed.
    func glideToSpotlightIfIdle(elapsed: TimeInterval) {
        guard elapsed >= CatTimingConstants.idleToSpotlightThreshold,
              currentState.isRestState,
              !isLoadingActive,
              !isDragging,
              !isDismissed,
              !isAtSpotlight
        else { return }
        glideToSpotlight()
    }

    private func glideToSpotlight() {
        spotlightAnimStartX = catPositionX
        spotlightAnimStartY = catPositionY
        spotlightAnimStartTime = Date()
        spotlightAnimDuration = CatTimingConstants.spotlightGlideDuration

        withAnimation(
            .easeInOut(duration: CatTimingConstants.spotlightGlideDuration)
        ) {
            self.catPositionX = self.spotlightX
            self.catPositionY = self.spotlightY
        }
        updateHomeBase()
    }

    // MARK: - Snap (reaction state, sejak muncul)

    /// Reaction langsung muncul di spotlight. Skip saat kucing sedang
    /// dipegang (drag) atau sudah dibuang — jangan rebut posisi dari user.
    func snapToSpotlightForReaction() {
        guard !isDragging, !isDismissed else { return }
        spotlightAnimDuration = 0
        var transaction = SwiftUI.Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            self.catPositionX = self.spotlightX
            self.catPositionY = self.spotlightY
        }
        updateHomeBase()
    }

    // MARK: - Glide Interpolation (hit testing + interrupt)

    /// Posisi visual saat glide masih berjalan; nil jika tidak ada glide
    /// aktif (posisi visual = catPositionX/Y biasa). Curve mengaproksimasi
    /// easeInOut agar interactive rect mengikuti posisi visual.
    var spotlightGlideVisualPosition: CGPoint? {
        guard spotlightAnimDuration > 0 else { return nil }
        let elapsed = Date().timeIntervalSince(spotlightAnimStartTime)
        let t = CGFloat(elapsed / spotlightAnimDuration)
        guard t < 1.0 else { return nil }
        let inverse = -2 * t + 2
        let eased: CGFloat = t < 0.5
            ? 2 * t * t
            : 1 - inverse * inverse / 2
        return CGPoint(
            x: spotlightAnimStartX + (spotlightX - spotlightAnimStartX) * eased,
            y: spotlightAnimStartY + (spotlightY - spotlightAnimStartY) * eased
        )
    }

    /// Drag dimulai di tengah glide → bekukan posisi di titik visual saat ini
    /// supaya kucing tidak "lompat" ke target spotlight di bawah jari user.
    func snapToCurrentGlidePosition() {
        guard let visual = spotlightGlideVisualPosition else { return }
        spotlightAnimDuration = 0
        var transaction = SwiftUI.Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            self.catPositionX = visual.x
            self.catPositionY = visual.y
        }
    }
}
