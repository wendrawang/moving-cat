import Combine
import CoreGraphics
import Foundation
import SwiftUI

// MARK: - Spotlight Presence (AFK Appear / Tap Hide)
//
// Model "screensaver":
//   - Kucing DEFAULT sembunyi (isSpotlightPresent = false).
//   - User AFK (tanpa sentuhan) >= afkAppearThreshold → kucing muncul di
//     spotlight (tengah layar + sorot lampu), lalu looping 3 exercise
//     (warmup/pushup/starJump) terus lewat rotasi idle timer.
//   - User menyentuh layar di luar kucing → kucing sembunyi lagi, AFK
//     timer restart (muncul lagi setelah AFK berikutnya).
//   - Reaction (transaksi sukses/gagal/exhausted) juga muncul di spotlight.

extension CatBehaviorEngine {

    // MARK: - Spotlight Coordinates

    var spotlightX: CGFloat { screenWidth * CatLayoutConstants.spotlightXRatio }
    var spotlightY: CGFloat { screenHeight * CatLayoutConstants.spotlightYRatio }

    // MARK: - Idle Enable / Disable (per halaman)

    /// Aktifkan/nonaktifkan kemunculan otomatis kucing saat AFK.
    /// - true  : mulai hitung AFK lagi bila kucing sedang sembunyi.
    /// - false : stop AFK; jika sedang looping (bukan mid-reaction) → sembunyikan.
    func setSpotlightIdleEnabled(_ enabled: Bool) {
        guard enabled != isSpotlightIdleEnabled else { return }
        isSpotlightIdleEnabled = enabled

        if enabled {
            if !isSpotlightPresent && !isDismissed { startAfkTimer() }
        } else {
            stopAfkTimer()
            if isSpotlightPresent && currentState.isRestState {
                hideFromSpotlight()
            }
        }
    }

    // MARK: - AFK Timer

    /// Mulai menghitung AFK. Setiap tick tanpa sentuhan menambah counter;
    /// begitu mencapai threshold dan kucing masih sembunyi → muncul.
    func startAfkTimer() {
        afkElapsedSeconds = 0
        afkTimerCancellable?.cancel()
        afkTimerCancellable = Timer.publish(
            every: CatTimingConstants.idleTickInterval,
            on: .main, in: .common
        )
        .autoconnect()
        .sink { [weak self] _ in
            guard let self = self else { return }
            self.afkElapsedSeconds += CatTimingConstants.idleTickInterval
            if self.afkElapsedSeconds >= CatTimingConstants.afkAppearThreshold {
                self.appearForIdle()
            }
        }
    }

    func stopAfkTimer() {
        afkTimerCancellable?.cancel()
        afkTimerCancellable = nil
        afkElapsedSeconds = 0
    }

    // MARK: - User Activity (dipanggil dari window untuk SETIAP sentuhan)

    /// `isOnCat`: true jika sentuhan mengenai kucing (buka passport/drag),
    /// false jika di area lain (→ sembunyikan kucing).
    func registerUserActivity(isOnCat: Bool) {
        afkElapsedSeconds = 0

        guard isSpotlightPresent, !isOnCat else { return }
        // Jangan sembunyikan saat modal terbuka (passport/voucher) — modal
        // punya cara dismiss sendiri.
        guard !isPassportVisible, !isVoucherOverlayVisible else { return }

        // Ubah @Published di luar hitTest pass (hindari mutasi saat layout).
        DispatchQueue.main.async { [weak self] in
            self?.hideFromSpotlight()
        }
    }

    // MARK: - Appear (idle / AFK)

    /// Kucing muncul di spotlight karena user AFK, lalu looping exercise.
    func appearForIdle() {
        guard isSpotlightIdleEnabled, !isDismissed, !isSpotlightPresent else {
            return
        }
        showInSpotlight()

        // Mulai fresh dari rest state acak + rotasi 3 exercise.
        let restState = stateMachine.nextRestState()
        setCurrentState(restState)
        stateMachine.applyTransition(
            CatTransitionResult(newState: restState, sideEffects: [])
        )
        CatAudioManager.shared.play(.idle)
        idleElapsedSeconds = 0
        startIdleTimer()
    }

    // MARK: - Appear (reaction)

    /// Reaction (happy/sad/annoyed/exhausted) tampil di spotlight sejak
    /// muncul. Skip saat kucing sedang di-drag atau sudah dibuang.
    func snapToSpotlightForReaction() {
        guard !isDragging, !isDismissed else { return }
        showInSpotlight()
    }

    // MARK: - Show / Hide Core

    /// Pindahkan kucing ke spotlight (instan, tanpa animasi posisi) lalu
    /// fade-in presence + sorot lampu. Hentikan AFK timer selama tampil.
    func showInSpotlight() {
        stopAfkTimer()

        var positionTransaction = SwiftUI.Transaction()
        positionTransaction.disablesAnimations = true
        withTransaction(positionTransaction) {
            self.setCatPositionX(self.spotlightX)
            self.setCatPositionY(self.spotlightY)
        }
        updateHomeBase()

        if !isSpotlightPresent {
            withAnimation(
                .easeOut(duration: CatTimingConstants.spotlightAppearDuration)
            ) {
                self.setSpotlightPresent(true)
            }
        }
    }

    /// Sembunyikan kucing (fade-out), hentikan rotasi. AFK timer hanya
    /// di-arm ulang jika idle-spotlight masih diizinkan (page aktif).
    func hideFromSpotlight() {
        guard isSpotlightPresent else { return }
        withAnimation(
            .easeIn(duration: CatTimingConstants.spotlightHideDuration)
        ) {
            self.setSpotlightPresent(false)
        }
        stopIdleTimer()
        cancelPendingAnimations()
        CatAudioManager.shared.stopLoop()
        if isSpotlightIdleEnabled { startAfkTimer() }
    }
}
