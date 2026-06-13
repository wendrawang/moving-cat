import AVFoundation
import Foundation
import UIKit

// MARK: - CatAudioManager
//
// Singleton audio manager untuk CuanCat overlay.
//
// Arsitektur:
//   - Preload semua player di background thread saat init, sorted by preloadPriority.
//     Tap & reaction sounds di-load lebih dulu agar latency tap ~0ms.
//   - File tidak ada di bundle = type tersebut no-op otomatis (feature flag by file presence).
//   - Loop (idle, walk): dikelola via currentLoop.
//   - play(_:) selalu stop semua audio dulu → transisi bersih, tidak ada overlap.
//   - Loop yang sama sedang play → idempotent, tidak restart.
//   - AVAudioSession .ambient: respect silent/ringer switch, bisa mix dengan music/call.
//   - Handle app background (stop) dan audio session interruption (telepon masuk).
//   - Semua play/stop harus dari main thread. prepareToPlay() aman di background.

final class CatAudioManager {

    static let shared = CatAudioManager()

    // Diakses dari main thread setelah preload selesai
    private var players: [CatSoundType: AVAudioPlayer] = [:]
    private var currentLoop: AVAudioPlayer?

    // Proteksi cross-thread saat background load → main read
    private let lock = NSLock()

    private var backgroundObserver: Any?
    private var interruptionObserver: Any?

    private init() {
        configureSession()
        preloadByPriority()
        observeLifecycle()
    }

    // MARK: - Prepare

    /// Pastikan singleton sudah di-init sebelum overlay muncul pertama kali.
    /// Panggil dari CatOverlayManager.prepare() agar preload selesai lebih awal.
    func prepare() {
        // Body kosong — preload sudah kick off di init().
        // Akses .shared ini cukup untuk trigger init.
    }

    // MARK: - Session

    private func configureSession() {
        try? AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default)
        try? AVAudioSession.sharedInstance().setActive(true)
    }

    // MARK: - Preload

    private func preloadByPriority() {
        let sorted = CatSoundType.allCases.sorted { $0.preloadPriority < $1.preloadPriority }
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            sorted.forEach { self?.loadPlayer(for: $0) }
        }
    }

    private func loadPlayer(for type: CatSoundType) {
        guard
            let url = Bundle.main.url(forResource: type.rawValue, withExtension: "wav"),
            let player = try? AVAudioPlayer(contentsOf: url)
        else { return }  // File tidak ada → type ini no-op

        player.numberOfLoops = type.loops ? -1 : 0
        player.volume = type.volume
        // prepareToPlay() buffer audio ke memory — aman di background per dokumentasi.
        // Tanpa ini, play() pertama kali butuh ~50-100ms extra untuk init audio queue.
        player.prepareToPlay()

        lock.lock()
        players[type] = player
        lock.unlock()
    }

    // MARK: - Public API (main thread only)

    /// Mainkan sound.
    ///
    /// Loop (idle, walk):
    ///   Stop semua audio → start loop. Idempotent jika loop yang sama sudah berjalan.
    ///
    /// Overlay one-shot (tapMeow, tapVoucher):
    ///   Play di atas loop aktif — loop TIDAK di-stop. Restart jika tap cepat.
    ///
    /// State-change one-shot (happy, sad, annoyed, exhausted):
    ///   Stop semua termasuk loop, lalu play sekali.
    ///
    /// No-op jika file tidak ada di bundle.
    func play(_ type: CatSoundType) {
        lock.lock()
        let player = players[type]
        let allPlayers = players
        lock.unlock()

        // PENTING: stop lama SEBELUM guard.
        // Kalau guard dulu, file tidak ada → return lebih awal → loop lama tidak pernah di-stop.
        // Contoh: walk sound ada, idle sound tidak ada → play(.idle) harus tetap stop walk loop.
        if type.loops {
            // Loop yang sama sudah aktif → idempotent, tidak perlu restart
            if let samePlayer = player, currentLoop === samePlayer, samePlayer.isPlaying { return }
            allPlayers.values.forEach { $0.stop() }
            currentLoop = nil
        } else if !type.isOverlay {
            // State-change one-shot: selalu stop loop + semua audio aktif
            allPlayers.values.forEach { $0.stop() }
            currentLoop = nil
        }
        // Overlay (tap sounds): tidak stop apapun selain dirinya sendiri (di bawah)

        guard let player = player else { return }  // File tidak ada → stop sudah, tidak perlu start

        if type.isOverlay { player.stop() }  // Restart jika tap cepat
        player.currentTime = 0
        player.play()

        if type.loops {
            currentLoop = player
        }
    }

    /// Stop loop yang sedang berjalan tanpa start yang baru.
    /// Gunakan saat cat di-dismiss (akan bringBack nanti, loop akan restart).
    func stopLoop() {
        currentLoop?.stop()
        currentLoop = nil
    }

    /// Stop semua audio.
    /// Gunakan saat overlay di-hide permanen atau app masuk background.
    func stopAll() {
        lock.lock()
        let snapshot = players
        lock.unlock()

        snapshot.values.forEach { $0.stop() }
        currentLoop = nil
    }

    // MARK: - Lifecycle

    private func observeLifecycle() {
        backgroundObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.stopAll()
        }

        interruptionObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.handleInterruption(notification)
        }
    }

    private func handleInterruption(_ notification: Notification) {
        guard
            let info = notification.userInfo,
            let typeValue = info[AVAudioSessionInterruptionTypeKey] as? UInt,
            let type = AVAudioSession.InterruptionType(rawValue: typeValue)
        else { return }

        switch type {
        case .began:
            stopAll()
        case .ended:
            try? AVAudioSession.sharedInstance().setActive(true)
        @unknown default:
            break
        }
    }

    deinit {
        [backgroundObserver, interruptionObserver]
            .compactMap { $0 }
            .forEach { NotificationCenter.default.removeObserver($0) }
    }
}
