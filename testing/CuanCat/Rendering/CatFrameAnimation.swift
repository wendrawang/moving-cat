import Foundation
import Lottie
import UIKit

// MARK: - CatLoadedAnimation
//
// Dua format animasi yang didukung (dideteksi otomatis dari isi JSON):
//   - frames : "Image to Lottie" frame-dump — tiap frame gambar base64 di `assets`.
//              Diputar via CatStreamingView (CADisplayLink + prefetch decode).
//   - vector : Lottie vector asli (layers berisi shapes, tanpa base64).
//              Diputar via Lottie AnimationView (CoreAnimation, GPU-composited).

enum CatLoadedAnimation {
    case frames(CatFrameAnimation)
    case vector(Lottie.Animation)
}

// MARK: - CatFrameAnimation
//
// Menyimpan compressed frame bytes dari JSON (format frame-dump).
// TIDAK decode ke bitmap saat init — decode hanya saat frame ditampilkan.
// Memory: ~4–5MB per animasi (compressed), bukan 300–650MB (decoded semua).

final class CatFrameAnimation {

    let name: String
    let frameCount: Int
    let fps: Double
    let loops: Bool

    // Compressed WebP per frame (~8–12KB each).
    // Disimpan sebagai Data, bukan UIImage — belum di-decode ke bitmap.
    private let compressedFrames: [Data]

    init?(name: String, loops: Bool) {
        guard
            let url = Bundle.main.url(forResource: name, withExtension: "json"),
            let jsonData = try? Data(contentsOf: url),
            let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
            let assets = json["assets"] as? [[String: Any]],
            let fps = json["fr"] as? Double,
            !assets.isEmpty
        else { return nil }

        self.name = name
        self.fps = fps
        self.loops = loops
        self.frameCount = assets.count

        var frames: [Data] = []
        frames.reserveCapacity(assets.count)

        for asset in assets {
            guard
                let path = asset["p"] as? String,
                let range = path.range(of: "base64,"),
                let data = Data(
                    base64Encoded: String(path[range.upperBound...]),
                    options: .ignoreUnknownCharacters
                )
            else {
                // Ada asset TANPA base64 → ini BUKAN frame-dump ("Image to Lottie").
                // Vector Lottie asli juga bisa punya assets (precomp/image refs).
                // Return nil agar caller fallback ke parser vector (library Lottie).
                return nil
            }
            frames.append(data)
        }

        self.compressedFrames = frames
    }

    /// Decode 1 frame on-demand. Dipanggil tiap tick — ~0.3ms di A-series chip.
    /// Catatan: decompression bitmap sebenarnya baru terjadi saat render commit.
    func image(at index: Int) -> UIImage? {
        guard index < compressedFrames.count,
              !compressedFrames[index].isEmpty else { return nil }
        return UIImage(data: compressedFrames[index])
    }

    /// Decode + PAKSA decompress bitmap — untuk prefetch di background thread.
    /// Tanpa ini, decompression terjadi di main thread saat CA commit (jank source).
    func decodedImage(at index: Int) -> UIImage? {
        guard let rawImage = image(at: index) else { return nil }
        if #available(iOS 15.0, *) {
            return rawImage.preparingForDisplay() ?? rawImage
        }
        // iOS 13/14: paksa decode dengan redraw ke bitmap context (thread-safe off-main)
        let format = UIGraphicsImageRendererFormat()
        format.scale = rawImage.scale
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(size: rawImage.size, format: format)
        return renderer.image { _ in rawImage.draw(at: .zero) }
    }
}

// MARK: - CatAnimationCache
//
// Singleton cache untuk CatLoadedAnimation (frames ATAU vector).
// Strategy:
//   - rest pool (warmup/pushup/starJump) → preload duluan (default awal kucing)
//   - idle (fallback) → preload setelahnya (berurutan, tidak berebut CPU)
//   - lainnya → lazy load saat pertama kali dibutuhkan
//
// Cache tidak pernah di-evict selama app hidup (~20MB total).
// Trade-off yang acceptable vs 3GB kalau semua di-decode sekaligus.

final class CatAnimationCache {

    static let shared = CatAnimationCache()

    private var cache: [String: CatLoadedAnimation] = [:]
    private var loading: Set<String> = []
    private let lock = NSLock()

    // Completion callbacks yang menunggu load selesai
    private var pendingCallbacks: [String: [() -> Void]] = [:]

    private init() {}

    // MARK: - Preload (eager)

    /// Preload berurutan: rest pool dulu (default awal), lalu idle (fallback).
    /// Walk TIDAK di-preload — auto-walking nonaktif, lazy load jika diaktifkan.
    /// Berurutan (chain) agar tidak berebut CPU saat app launch.
    /// Dipanggil dari CatOverlayManager.prepare().
    func preloadEager() {
        let names = [
            CatAssetManifest.warmup,
            CatAssetManifest.pushup,
            CatAssetManifest.starJump,
            CatAssetManifest.idle
        ]
        preloadChain(names: names, index: 0)
    }

    private func preloadChain(names: [String], index: Int) {
        guard index < names.count else { return }
        load(name: names[index], loops: true) { [weak self] in
            self?.preloadChain(names: names, index: index + 1)
        }
    }

    // MARK: - Lazy Load

    /// Ambil dari cache. Kalau belum ada, trigger load di background
    /// dan panggil completion saat siap.
    /// Jika asset tidak ditemukan di bundle → fallback ke animasi idle
    /// agar kucing tetap render (mis. file asset belum ditambahkan).
    func get(
        name: String,
        loops: Bool,
        completion: @escaping (CatLoadedAnimation) -> Void
    ) {
        lock.lock()
        if let cached = cache[name] {
            lock.unlock()
            completion(cached)
            return
        }
        lock.unlock()

        // Belum di-cache — load async
        load(name: name, loops: loops) {
            self.lock.lock()
            let anim = self.cache[name]
            self.lock.unlock()

            if let anim = anim {
                completion(anim)
            } else if name != CatAssetManifest.idle {
                // Asset hilang dari bundle — fallback ke idle, jangan blank
                self.get(name: CatAssetManifest.idle, loops: true, completion: completion)
            }
        }
    }

    // MARK: - Internal Load

    private func load(name: String, loops: Bool, completion: (() -> Void)?) {
        lock.lock()

        // Sudah di-cache
        if cache[name] != nil {
            lock.unlock()
            completion?()
            return
        }

        // Sedang di-load, daftarkan callback
        if loading.contains(name) {
            if let callback = completion {
                pendingCallbacks[name, default: []].append(callback)
            }
            lock.unlock()
            return
        }

        // Mulai load
        loading.insert(name)
        if let callback = completion {
            pendingCallbacks[name, default: []].append(callback)
        }
        lock.unlock()

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            // JSON parsing terjadi di sini — tidak di main thread.
            // Coba format frame-dump dulu (base64 assets); kalau bukan,
            // parse sebagai vector Lottie asli via library Lottie.
            let loaded: CatLoadedAnimation?
            if let frameAnim = CatFrameAnimation(name: name, loops: loops) {
                loaded = .frames(frameAnim)
            } else if let vectorAnim = Lottie.Animation.named(name) {
                loaded = .vector(vectorAnim)
            } else {
                loaded = nil
            }

            self.lock.lock()
            if let loaded = loaded { self.cache[name] = loaded }
            self.loading.remove(name)
            let callbacks = self.pendingCallbacks.removeValue(forKey: name) ?? []
            self.lock.unlock()

            DispatchQueue.main.async {
                callbacks.forEach { $0() }
            }
        }
    }
}
