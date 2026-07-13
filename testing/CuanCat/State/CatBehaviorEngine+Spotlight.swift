import CoreGraphics
import Foundation
import SwiftUI

// MARK: - Spotlight Glide Animation Snapshot

/// Snapshot glide ke spotlight yang sedang berjalan — dipakai interpolasi
/// manual (hit testing + interrupt drag) selama animasi SwiftUI jalan.
struct SpotlightGlideAnimation {
    let startPositionX: CGFloat
    let startPositionY: CGFloat
    let startTime: Date
    let duration: TimeInterval
}

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
        spotlightGlideAnimation = SpotlightGlideAnimation(
            startPositionX: catPositionX,
            startPositionY: catPositionY,
            startTime: Date(),
            duration: CatTimingConstants.spotlightGlideDuration
        )

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
        spotlightGlideAnimation = nil
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
        guard let glide = spotlightGlideAnimation, glide.duration > 0 else {
            return nil
        }
        let elapsedSeconds = Date().timeIntervalSince(glide.startTime)
        let linearProgress = CGFloat(elapsedSeconds / glide.duration)
        guard linearProgress < 1.0 else { return nil }
        let inverseProgress = -2 * linearProgress + 2
        let easedProgress: CGFloat = linearProgress < 0.5
            ? 2 * linearProgress * linearProgress
            : 1 - inverseProgress * inverseProgress / 2
        return CGPoint(
            x: glide.startPositionX
                + (spotlightX - glide.startPositionX) * easedProgress,
            y: glide.startPositionY
                + (spotlightY - glide.startPositionY) * easedProgress
        )
    }

    /// Drag dimulai di tengah glide → bekukan posisi di titik visual saat ini
    /// supaya kucing tidak "lompat" ke target spotlight di bawah jari user.
    func snapToCurrentGlidePosition() {
        guard let visualPosition = spotlightGlideVisualPosition else { return }
        spotlightGlideAnimation = nil
        var transaction = SwiftUI.Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            self.catPositionX = visualPosition.x
            self.catPositionY = visualPosition.y
        }
    }
}
