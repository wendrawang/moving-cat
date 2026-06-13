import SwiftUI

// MARK: - Confetti View (iOS 13 compatible)

struct ConfettiView: View {

    private let particleCount = 30
    @State private var particles: [ConfettiParticle] = []
    @State private var animating: Bool = false

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(self.particles) { particle in
                    self.particleView(
                        particle: particle,
                        screenSize: geometry.size
                    )
                }
            }
            .onAppear {
                self.particles = self.generateParticles(
                    count: self.particleCount,
                    screenWidth: geometry.size.width
                )
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    withAnimation(Animation.easeOut(duration: 2.5)) {
                        self.animating = true
                    }
                }
            }
        }
        .allowsHitTesting(false)
    }

    private func particleView(
        particle: ConfettiParticle,
        screenSize: CGSize
    ) -> some View {
        let startX = screenSize.width / 2 + particle.spreadX * 0.1
        let startY = screenSize.height * 0.4
        let endX = screenSize.width / 2 + particle.spreadX
        let endY = screenSize.height * 0.4 + particle.fallDistance

        return RoundedRectangle(cornerRadius: 2)
            .fill(particle.color)
            .frame(
                width: particle.size,
                height: particle.size * particle.aspectRatio
            )
            .rotationEffect(.degrees(animating ? particle.rotation : 0))
            .position(
                x: animating ? endX : startX,
                y: animating ? endY : startY
            )
            .opacity(animating ? 0.0 : 1.0)
    }

    private func generateParticles(
        count: Int,
        screenWidth: CGFloat
    ) -> [ConfettiParticle] {
        let colors: [Color] = [
            Color(red: 1.0, green: 0.84, blue: 0.0),
            Color(red: 1.0, green: 0.60, blue: 0.0),
            Color(red: 1.0, green: 0.40, blue: 0.40),
            Color(red: 0.40, green: 0.80, blue: 1.0),
            Color(red: 0.60, green: 1.0, blue: 0.60),
            Color(red: 0.90, green: 0.50, blue: 1.0)
        ]

        return (0..<count).map { idx in
            ConfettiParticle(
                identifier: idx,
                color: colors.randomElement() ?? .yellow,
                spreadX: CGFloat.random(in: -screenWidth * 0.5...screenWidth * 0.5),
                fallDistance: CGFloat.random(in: 200...500),
                rotation: Double.random(in: -720...720),
                size: CGFloat.random(in: 6...12),
                aspectRatio: CGFloat.random(in: 0.4...2.5)
            )
        }
    }
}

// MARK: - Confetti Particle Model

private struct ConfettiParticle: Identifiable {
    let identifier: Int
    let color: Color
    let spreadX: CGFloat
    let fallDistance: CGFloat
    let rotation: Double
    let size: CGFloat
    let aspectRatio: CGFloat

    var id: Int { identifier }
}
