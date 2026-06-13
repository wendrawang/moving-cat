import UIKit

// MARK: - DisplayLinkProxy
//
// Weak proxy untuk CADisplayLink agar tidak ada retain cycle:
// CADisplayLink → DisplayLinkProxy (strong) → CatStreamingView (weak).
// Tanpa proxy, CADisplayLink memegang target kuat sehingga CatStreamingView
// tidak bisa di-dealloc dan deinit tidak pernah dipanggil.

final class DisplayLinkProxy: NSObject {
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
        let view = UIImageView()
        view.contentMode = .scaleAspectFit
        view.backgroundColor = .clear
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private var displayLink: CADisplayLink?
    private var animation: CatFrameAnimation?
    private var currentFrame: Int = 0
    private var frameAccumulator: Double = 0
    private var lastTimestamp: Double = 0

    // MARK: - Frame Prefetch
    // Frame berikutnya di-decode + force-decompress di background queue,
    // sehingga main thread tinggal assign image (zero decode jank → stabil 60fps).
    private var prefetchedImage: UIImage?
    private var prefetchedIndex: Int = -1
    private var prefetchRequestedIndex: Int = -1
    private static let decodeQueue = DispatchQueue(
        label: "cuancat.frame.decode", qos: .userInteractive
    )

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
        resetPrefetch()

        // Frame pertama langsung tampil — tidak ada blank flash
        imageView.image = animation.image(at: 0)
        prefetchNextFrame(after: 0, animation: animation)

        // Gunakan proxy untuk menghindari retain cycle:
        // CADisplayLink → proxy (strong) → CatStreamingView (weak)
        // Tanpa proxy: CADisplayLink → CatStreamingView (strong) → displayLink → cycle,
        // menyebabkan deinit tidak pernah dipanggil dan display link jalan selamanya.
        let proxy = DisplayLinkProxy()
        proxy.view = self
        let link = CADisplayLink(target: proxy, selector: #selector(DisplayLinkProxy.fire(_:)))
        // Display link jalan di 60fps untuk frame pacing presisi (jitter ±16ms,
        // bukan ±33ms). Decode tetap mengikuti fps animasi (30fps) via accumulator —
        // tick tanpa frame baru langsung early-exit, jadi CPU cost tetap minimal.
        if #available(iOS 15.0, *) {
            link.preferredFrameRateRange = CAFrameRateRange(
                minimum: 30, maximum: 60, preferred: 60
            )
        } else {
            link.preferredFramesPerSecond = 60
        }
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    func stop() {
        stopLink()
        imageView.image = nil
        animation = nil
        resetPrefetch()
    }

    // MARK: - Tick

    func tick(_ link: CADisplayLink) {
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

        // Pakai frame hasil prefetch jika cocok (sudah decoded di background).
        // Kalau miss (frame skip), fallback decode sinkron seperti sebelumnya.
        // Frame sebelumnya langsung released karena imageView.image di-replace.
        if prefetchedIndex == currentFrame, let readyImage = prefetchedImage {
            imageView.image = readyImage
        } else {
            imageView.image = anim.image(at: currentFrame)
        }
        prefetchNextFrame(after: currentFrame, animation: anim)
    }

    // MARK: - Prefetch

    private func prefetchNextFrame(after index: Int, animation anim: CatFrameAnimation) {
        let nextIndex = anim.loops
            ? (index + 1) % anim.frameCount
            : min(index + 1, anim.frameCount - 1)
        guard nextIndex != index, prefetchRequestedIndex != nextIndex else { return }
        prefetchRequestedIndex = nextIndex

        Self.decodeQueue.async { [weak self] in
            let decoded = anim.decodedImage(at: nextIndex)
            DispatchQueue.main.async {
                guard let self = self, self.animation === anim else { return }
                self.prefetchedImage = decoded
                self.prefetchedIndex = nextIndex
            }
        }
    }

    private func resetPrefetch() {
        prefetchedImage = nil
        prefetchedIndex = -1
        prefetchRequestedIndex = -1
    }

    private func stopLink() {
        displayLink?.invalidate()
        displayLink = nil
    }

    deinit { stopLink() }
}
