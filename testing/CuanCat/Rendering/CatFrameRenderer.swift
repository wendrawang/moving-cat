//
//  CatFrameRenderer.swift
//  testing
//
//  Created by Wen on 14/05/26.
//

import UIKit
import SwiftUI

// MARK: - CatFrameAnimation
//
// Menyimpan compressed frame bytes dari JSON.
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
                frames.append(Data())
                continue
            }
            frames.append(data)
        }

        self.compressedFrames = frames
    }

    /// Decode 1 frame on-demand. Dipanggil tiap tick — ~0.3ms di A-series chip.
    func image(at index: Int) -> UIImage? {
        guard index < compressedFrames.count,
              !compressedFrames[index].isEmpty else { return nil }
        return UIImage(data: compressedFrames[index])
    }
}

// MARK: - CatAnimationCache
//
// Singleton cache untuk CatFrameAnimation objects.
// Strategy:
//   - idle  → preload saat prepare() dipanggil (paling sering dipakai)
//   - walk  → preload segera setelah idle selesai
//   - lainnya → lazy load saat pertama kali dibutuhkan
//
// Cache tidak pernah di-evict selama app hidup (~20MB total untuk 6 animasi).
// Trade-off yang acceptable vs 3GB kalau semua di-decode sekaligus.

final class CatAnimationCache {

    static let shared = CatAnimationCache()

    private var cache: [String: CatFrameAnimation] = [:]
    private var loading: Set<String> = []
    private let lock = NSLock()

    // Completion callbacks yang menunggu load selesai
    private var pendingCallbacks: [String: [() -> Void]] = [:]

    private init() {}

    // MARK: - Preload (eager)

    /// Preload idle sekarang, walk setelah idle selesai.
    /// Dipanggil dari CatOverlayManager.prepare().
    func preloadEager() {
        let idleName = CatAssetManifest.idle
        let walkName = CatAssetManifest.walk

        load(name: idleName, loops: true) {
            // Walk mulai load setelah idle selesai — tidak berebut CPU
            self.load(name: walkName, loops: true, completion: nil)
        }
    }

    // MARK: - Lazy Load

    /// Ambil dari cache. Kalau belum ada, trigger load di background
    /// dan panggil completion saat siap.
    func get(
        name: String,
        loops: Bool,
        completion: @escaping (CatFrameAnimation) -> Void
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
            if let anim = anim { completion(anim) }
        }
    }

    /// Synchronous get — hanya untuk kasus dimana sudah pasti di-cache.
    func getCached(name: String) -> CatFrameAnimation? {
        lock.lock()
        defer { lock.unlock() }
        return cache[name]
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
            if let cb = completion {
                pendingCallbacks[name, default: []].append(cb)
            }
            lock.unlock()
            return
        }

        // Mulai load
        loading.insert(name)
        if let cb = completion {
            pendingCallbacks[name, default: []].append(cb)
        }
        lock.unlock()

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            // JSON parsing + base64 extract terjadi di sini — tidak di main thread
            let anim = CatFrameAnimation(name: name, loops: loops)

            self.lock.lock()
            if let anim = anim { self.cache[name] = anim }
            self.loading.remove(name)
            let callbacks = self.pendingCallbacks.removeValue(forKey: name) ?? []
            self.lock.unlock()

            DispatchQueue.main.async {
                callbacks.forEach { $0() }
            }
        }
    }
}

// MARK: - DisplayLinkProxy
//
// Weak proxy untuk CADisplayLink agar tidak ada retain cycle:
// CADisplayLink → DisplayLinkProxy (strong) → CatStreamingView (weak).
// Tanpa proxy, CADisplayLink memegang target kuat sehingga CatStreamingView
// tidak bisa di-dealloc dan deinit tidak pernah dipanggil.

private final class DisplayLinkProxy: NSObject {
    weak var view: CatStreamingView?
    @objc func fire(_ link: CADisplayLink) { view?.tick(link) }
}

// MARK: - CatStreamingView
//
// UIView yang memutar animasi frame-by-frame via CADisplayLink.
// Hanya 1 frame di-decode dan di-hold di memory pada satu waktu.
// Frame sebelumnya langsung di-release saat imageView.image di-replace.

final class CatStreamingView: UIView {

    private let imageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFit
        iv.backgroundColor = .clear
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()

    private var displayLink: CADisplayLink?
    private var animation: CatFrameAnimation?
    private var currentFrame: Int = 0
    private var frameAccumulator: Double = 0
    private var lastTimestamp: Double = 0

    var onAnimationEnd: (() -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        addSubview(imageView)
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: topAnchor),
            imageView.bottomAnchor.constraint(equalTo: bottomAnchor),
            imageView.leadingAnchor.constraint(equalTo: leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: trailingAnchor)
        ])
        backgroundColor = .clear
        isOpaque = false
        isUserInteractionEnabled = false
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Playback

    func play(animation: CatFrameAnimation) {
        stopLink()
        self.animation = animation
        currentFrame = 0
        frameAccumulator = 0
        lastTimestamp = 0

        // Frame pertama langsung tampil — tidak ada blank flash
        imageView.image = animation.image(at: 0)

        // Gunakan proxy untuk menghindari retain cycle:
        // CADisplayLink → proxy (strong) → CatStreamingView (weak)
        // Tanpa proxy: CADisplayLink → CatStreamingView (strong) → displayLink → cycle,
        // menyebabkan deinit tidak pernah dipanggil dan display link jalan selamanya.
        let proxy = DisplayLinkProxy()
        proxy.view = self
        let link = CADisplayLink(target: proxy, selector: #selector(DisplayLinkProxy.fire(_:)))
        // Batasi ke 30fps — sesuai fps animasi, hemat CPU
        if #available(iOS 15.0, *) {
            link.preferredFrameRateRange = CAFrameRateRange(
                minimum: 30, maximum: 30, preferred: 30
            )
        } else {
            link.preferredFramesPerSecond = 30
        }
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    func stop() {
        stopLink()
        imageView.image = nil
        animation = nil
    }

    // MARK: - Tick

    fileprivate func tick(_ link: CADisplayLink) {
        guard let anim = animation else { return }

        if lastTimestamp == 0 {
            lastTimestamp = link.timestamp
            return
        }

        // Cap delta agar frame tidak lompat banyak setelah app resume dari background
        let delta = min(link.timestamp - lastTimestamp, 3.0 / anim.fps)
        lastTimestamp = link.timestamp
        frameAccumulator += delta * anim.fps

        let advance = Int(frameAccumulator)
        guard advance > 0 else { return }
        frameAccumulator -= Double(advance)

        let next = currentFrame + advance

        if next >= anim.frameCount {
            if anim.loops {
                currentFrame = next % anim.frameCount
            } else {
                currentFrame = anim.frameCount - 1
                imageView.image = anim.image(at: currentFrame)
                stopLink()
                onAnimationEnd?()
                return
            }
        } else {
            currentFrame = next
        }

        // Decode 1 frame — frame sebelumnya langsung released karena
        // imageView.image di-replace (ARC release reference lama)
        imageView.image = anim.image(at: currentFrame)
    }

    private func stopLink() {
        displayLink?.invalidate()
        displayLink = nil
    }

    deinit { stopLink() }
}

// MARK: - CatFrameContainerView
//
// Mengelola transisi antar animasi dengan crossfade.
// Hanya ada 2 CatStreamingView (current + next) — tidak pernah lebih.

final class CatFrameContainerView: UIView {

    private var activeView: CatStreamingView
    private var stagingView: CatStreamingView
    private(set) var currentName: String = ""
    var onFirstFrameReady: (() -> Void)?
    private var hasCalledFirstFrameReady = false
    private var crossfadeGeneration: Int = 0

    override init(frame: CGRect) {
        activeView = CatStreamingView()
        stagingView = CatStreamingView()
        super.init(frame: frame)
        backgroundColor = .clear
        isOpaque = false
        isUserInteractionEnabled = false

        for view in [activeView, stagingView] {
            addSubview(view)
            view.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                view.topAnchor.constraint(equalTo: topAnchor),
                view.bottomAnchor.constraint(equalTo: bottomAnchor),
                view.leadingAnchor.constraint(equalTo: leadingAnchor),
                view.trailingAnchor.constraint(equalTo: trailingAnchor)
            ])
        }
        stagingView.alpha = 0
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Load initial animation

    func loadInitial(name: String, loops: Bool) {
        currentName = name
        CatAnimationCache.shared.get(name: name, loops: loops) { [weak self] anim in
            guard let self = self else { return }
            self.activeView.play(animation: anim)
            if !self.hasCalledFirstFrameReady {
                self.hasCalledFirstFrameReady = true
                self.onFirstFrameReady?()
            }
        }
    }

    // MARK: - Transition to new animation

    func show(name: String, loops: Bool) {
        guard name != currentName else { return }
        let previousName = currentName
        currentName = name

        CatAnimationCache.shared.get(name: name, loops: loops) { [weak self] anim in
            guard let self = self, self.currentName == name else { return }
            self.crossfade(to: anim, previousName: previousName)
        }
    }

    private func crossfade(to anim: CatFrameAnimation, previousName: String) {
        crossfadeGeneration += 1
        let gen = crossfadeGeneration

        // stagingView mulai play animasi baru (alpha masih 0)
        stagingView.alpha = 0
        stagingView.play(animation: anim)

        UIView.animate(withDuration: 0.15, animations: {
            self.stagingView.alpha = 1
            self.activeView.alpha = 0
        }, completion: { _ in
            // Guard: jika crossfade baru sudah mulai sebelum ini selesai, skip swap.
            // Tanpa guard, 2 crossfade cepat (< 150ms) akan stop() kedua view sekaligus
            // sehingga animasi berhenti total dan kucing tidak terlihat.
            guard self.crossfadeGeneration == gen else { return }
            self.activeView.stop()
            self.activeView.alpha = 1
            swap(&self.activeView, &self.stagingView)
        })
    }

    // MARK: - Teardown

    /// Dipanggil dari CatFrameView.dismantleUIView saat SwiftUI melepas view.
    /// Menghentikan kedua display link agar retain cycle (via proxy) benar-benar terputus.
    func teardown() {
        activeView.stop()
        stagingView.stop()
    }
}

// MARK: - CatFrameRenderer (pengganti LottieCatRenderer)

struct CatFrameRenderer: CatRenderable {
    
    func makeBody(state: CatState, direction: CatDirection, onFirstFrameReady: (() -> Void)? = nil) -> some View {
        CatFrameView(
            animationName: CatAssetManifest.assetName(animation: state.animationType),
            loops: state.animationType.loops,
            scaleX: direction.scaleX,
            onFirstFrameReady: onFirstFrameReady
        )
        .frame(
            width: CatLayoutConstants.avatarSize,
            height: CatLayoutConstants.avatarSize
        )
    }
}

// MARK: - SwiftUI Wrapper

struct CatFrameView: UIViewRepresentable {

    let animationName: String
    let loops: Bool
    let scaleX: CGFloat
    var onFirstFrameReady: (() -> Void)?

    func makeUIView(context: Context) -> CatFrameContainerView {
        let view = CatFrameContainerView()
        view.transform = CGAffineTransform(scaleX: scaleX, y: 1)
        view.onFirstFrameReady = onFirstFrameReady
        view.loadInitial(name: animationName, loops: loops)
        return view
    }

    func updateUIView(_ uiView: CatFrameContainerView, context: Context) {
        if uiView.currentName != animationName {
            uiView.transform = CGAffineTransform(scaleX: scaleX, y: 1)
            uiView.show(name: animationName, loops: loops)
        } else if uiView.transform.a != scaleX {
            // Direction berubah tapi animasi sama (misal: walk balik arah)
            uiView.transform = CGAffineTransform(scaleX: scaleX, y: 1)
        }
    }

    static func dismantleUIView(_ uiView: CatFrameContainerView, coordinator: ()) {
        uiView.teardown()
    }
}
