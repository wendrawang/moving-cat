import SwiftUI

// MARK: - Spotlight Particles View
//
// Partikel cahaya lembut (seperti debu kena sorot lampu) yang melayang
// pelan naik-turun di dalam beam — bikin panggung terasa hidup, subtle.
// iOS 13 compatible: pakai animasi repeatForever di onAppear (bukan
// TimelineView/Canvas yang butuh iOS 15).

struct SpotlightParticlesView: View {

    private let particles: [SpotlightParticle] = SpotlightParticle.preset

    var body: some View {
        ZStack {
            ForEach(particles) { particle in
                SpotlightParticleDot(particle: particle)
            }
        }
        .frame(
            width: CatLayoutConstants.spotlightBeamBottomWidth,
            height: CatLayoutConstants.spotlightBeamHeight
        )
        .allowsHitTesting(false)
    }
}

// MARK: - Particle Model

struct SpotlightParticle: Identifiable {
    let id: Int
    let offsetX: CGFloat       // posisi X relatif tengah beam
    let baseY: CGFloat         // posisi Y awal relatif tengah beam
    let size: CGFloat
    let drift: CGFloat         // jarak naik saat animasi
    let minOpacity: Double
    let maxOpacity: Double
    let duration: Double
    let delay: Double

    /// Sebaran tetap (deterministik) supaya tidak "loncat" tiap re-render.
    static let preset: [SpotlightParticle] = [
        SpotlightParticle(id: 0, offsetX: -70, baseY: 60, size: 5,
                          drift: 26, minOpacity: 0.0, maxOpacity: 0.5,
                          duration: 3.8, delay: 0.0),
        SpotlightParticle(id: 1, offsetX: 48, baseY: 100, size: 4,
                          drift: 22, minOpacity: 0.0, maxOpacity: 0.45,
                          duration: 4.6, delay: 0.6),
        SpotlightParticle(id: 2, offsetX: -20, baseY: -30, size: 6,
                          drift: 30, minOpacity: 0.05, maxOpacity: 0.55,
                          duration: 4.1, delay: 1.2),
        SpotlightParticle(id: 3, offsetX: 82, baseY: 10, size: 3,
                          drift: 18, minOpacity: 0.0, maxOpacity: 0.4,
                          duration: 5.0, delay: 0.3),
        SpotlightParticle(id: 4, offsetX: -100, baseY: 130, size: 4,
                          drift: 24, minOpacity: 0.0, maxOpacity: 0.42,
                          duration: 4.3, delay: 1.8),
        SpotlightParticle(id: 5, offsetX: 18, baseY: 150, size: 5,
                          drift: 28, minOpacity: 0.0, maxOpacity: 0.5,
                          duration: 3.5, delay: 0.9),
        SpotlightParticle(id: 6, offsetX: 100, baseY: 80, size: 3,
                          drift: 20, minOpacity: 0.0, maxOpacity: 0.38,
                          duration: 4.8, delay: 1.5)
    ]
}

// MARK: - Single Particle Dot

private struct SpotlightParticleDot: View {

    let particle: SpotlightParticle
    @State private var animate = false

    var body: some View {
        Circle()
            .fill(Color.white)
            .frame(width: particle.size, height: particle.size)
            .blur(radius: particle.size * 0.5)
            .opacity(animate ? particle.maxOpacity : particle.minOpacity)
            .offset(
                x: particle.offsetX,
                y: animate ? particle.baseY - particle.drift : particle.baseY
            )
            .onAppear {
                withAnimation(
                    .easeInOut(duration: particle.duration)
                        .repeatForever(autoreverses: true)
                        .delay(particle.delay)
                ) {
                    animate = true
                }
            }
    }
}
