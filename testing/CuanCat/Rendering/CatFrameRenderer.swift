//
//  CatFrameRenderer.swift
//  testing
//
//  Created by Wen on 14/05/26.
//

import Lottie
import SwiftUI
import UIKit

// MARK: - CatFrameContainerView
//
// Mengelola transisi antar animasi dengan crossfade.
// Hybrid: tiap animasi dapat "slot" view sesuai formatnya —
//   frames → CatStreamingView, vector → Lottie AnimationView.
// Slot dibuat per transisi dan slot lama dibuang setelah crossfade,
// jadi maksimal hanya 2 slot hidup pada satu waktu.

final class CatFrameContainerView: UIView {

    private var activeSlot: UIView?
    private(set) var currentName: String = ""
    var onFirstFrameReady: (() -> Void)?
    private var hasCalledFirstFrameReady = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isOpaque = false
        isUserInteractionEnabled = false
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Slot Factory

    /// Buat view player sesuai format animasi, pasang full-size, langsung play.
    private func installSlot(
        with loaded: CatLoadedAnimation, loops: Bool
    ) -> UIView {
        let slot: UIView
        switch loaded {
        case .frames(let frameAnim):
            let streamingView = CatStreamingView()
            streamingView.play(animation: frameAnim)
            slot = streamingView

        case .vector(let vectorAnim):
            let animationView = AnimationView(animation: vectorAnim)
            animationView.loopMode = loops ? .loop : .playOnce
            animationView.contentMode = .scaleAspectFit
            // pauseAndRestore: animasi lanjut otomatis setelah app balik dari background
            animationView.backgroundBehavior = .pauseAndRestore
            animationView.isUserInteractionEnabled = false
            animationView.play()
            slot = animationView
        }

        slot.translatesAutoresizingMaskIntoConstraints = false
        addSubview(slot)
        NSLayoutConstraint.activate([
            slot.topAnchor.constraint(equalTo: topAnchor),
            slot.bottomAnchor.constraint(equalTo: bottomAnchor),
            slot.leadingAnchor.constraint(equalTo: leadingAnchor),
            slot.trailingAnchor.constraint(equalTo: trailingAnchor)
        ])
        return slot
    }

    private func stopPlayback(in slot: UIView?) {
        if let streamingView = slot as? CatStreamingView {
            streamingView.stop()
        } else if let animationView = slot as? AnimationView {
            animationView.stop()
        }
    }

    // MARK: - Load initial animation

    func loadInitial(name: String, loops: Bool) {
        currentName = name
        CatAnimationCache.shared.get(name: name, loops: loops) { [weak self] loaded in
            guard let self = self, self.currentName == name else { return }
            self.activeSlot = self.installSlot(with: loaded, loops: loops)
            if !self.hasCalledFirstFrameReady {
                self.hasCalledFirstFrameReady = true
                self.onFirstFrameReady?()
            }
        }
    }

    // MARK: - Transition to new animation

    func show(name: String, loops: Bool) {
        guard name != currentName else { return }
        currentName = name

        CatAnimationCache.shared.get(name: name, loops: loops) { [weak self] loaded in
            guard let self = self, self.currentName == name else { return }
            self.crossfade(to: loaded, loops: loops)
        }
    }

    private func crossfade(to loaded: CatLoadedAnimation, loops: Bool) {
        let oldSlot = activeSlot
        let newSlot = installSlot(with: loaded, loops: loops)
        newSlot.alpha = 0
        activeSlot = newSlot

        UIView.animate(withDuration: 0.15, animations: {
            newSlot.alpha = 1
            oldSlot?.alpha = 0
        }, completion: { _ in
            // Tiap crossfade membuang slot lamanya sendiri — dua crossfade cepat
            // (< 150ms) aman karena masing-masing pegang reference oldSlot berbeda.
            self.stopPlayback(in: oldSlot)
            oldSlot?.removeFromSuperview()
        })
    }

    // MARK: - Teardown

    /// Dipanggil dari CatFrameView.dismantleUIView saat SwiftUI melepas view.
    /// Menghentikan semua playback agar display link / CoreAnimation berhenti total.
    func teardown() {
        for slot in subviews {
            stopPlayback(in: slot)
        }
    }
}

// MARK: - CatFrameRenderer

struct CatFrameRenderer: CatRenderable {

    func makeBody(
        animation: CatAnimationType,
        direction: CatDirection,
        onFirstFrameReady: (() -> Void)? = nil
    ) -> some View {
        CatFrameView(
            animationName: CatAssetManifest.assetName(animation: animation),
            loops: animation.loops,
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
