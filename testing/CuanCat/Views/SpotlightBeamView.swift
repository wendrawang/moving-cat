import SwiftUI

// MARK: - Spotlight Beam View
//
// Efek "sorot lampu panggung" di belakang kucing saat tampil di spotlight:
//   - Cone: trapesium menyempit di atas (sumber lampu), melebar ke bawah,
//     dengan gradient vertikal yang memudar ke bawah.
//   - Floor glow: elips terang di kaki kucing.
// iOS 13 compatible: hanya pakai Path + LinearGradient + RadialGradient.

struct SpotlightBeamView: View {

    private var beamHeight: CGFloat { CatLayoutConstants.spotlightBeamHeight }
    private var topWidth: CGFloat { CatLayoutConstants.spotlightBeamTopWidth }
    private var bottomWidth: CGFloat { CatLayoutConstants.spotlightBeamBottomWidth }
    private var glowWidth: CGFloat { CatLayoutConstants.spotlightFloorGlowWidth }
    private var glowHeight: CGFloat { CatLayoutConstants.spotlightFloorGlowHeight }

    var body: some View {
        ZStack {
            beamCone
            floorGlow
        }
        .frame(width: bottomWidth, height: beamHeight)
        .allowsHitTesting(false)
    }

    // MARK: - Cone

    private var beamCone: some View {
        BeamConeShape(topWidth: topWidth, bottomWidth: bottomWidth)
            .fill(
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.white.opacity(0.34),
                        Color.white.opacity(0.12),
                        Color.white.opacity(0.0)
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .blur(radius: 8)
    }

    // MARK: - Floor Glow

    private var floorGlow: some View {
        Ellipse()
            .fill(
                RadialGradient(
                    gradient: Gradient(colors: [
                        Color.white.opacity(0.42),
                        Color.white.opacity(0.0)
                    ]),
                    center: .center,
                    startRadius: 0,
                    endRadius: glowWidth / 2
                )
            )
            .frame(width: glowWidth, height: glowHeight)
            .blur(radius: 6)
            .frame(height: beamHeight, alignment: .bottom)
    }
}

// MARK: - Beam Cone Shape (trapesium)

private struct BeamConeShape: Shape {

    let topWidth: CGFloat
    let bottomWidth: CGFloat

    func path(in rect: CGRect) -> Path {
        let centerX = rect.midX
        var path = Path()
        path.move(to: CGPoint(x: centerX - topWidth / 2, y: rect.minY))
        path.addLine(to: CGPoint(x: centerX + topWidth / 2, y: rect.minY))
        path.addLine(to: CGPoint(x: centerX + bottomWidth / 2, y: rect.maxY))
        path.addLine(to: CGPoint(x: centerX - bottomWidth / 2, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}
