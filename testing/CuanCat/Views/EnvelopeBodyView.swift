import SwiftUI

// MARK: - Envelope Body View

struct EnvelopeBodyView: View {

    let phase: Int

    private let envelopeWidth: CGFloat = 200
    private let envelopeHeight: CGFloat = 140

    private var flapHeight: CGFloat { envelopeHeight * 0.60 }
    private var flapOffset: CGFloat { -(envelopeHeight / 2 - flapHeight / 2) }
    private var sealOffsetY: CGFloat { flapOffset + flapHeight / 2 + 4 }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(red: 0.52, green: 0.31, blue: 0.06))
                .shadow(
                    color: Color(red: 0.35, green: 0.20, blue: 0.03).opacity(0.70),
                    radius: 18, y: 10
                )
                .frame(width: envelopeWidth, height: envelopeHeight)

            ZStack {
                Rectangle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color(red: 0.66, green: 0.43, blue: 0.11),
                                Color(red: 0.52, green: 0.31, blue: 0.07)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                EnvelopeLeftSideFold()
                    .fill(Color.black.opacity(0.10))

                EnvelopeRightSideFold()
                    .fill(Color.white.opacity(0.04))

                EnvelopeBottomFold()
                    .fill(Color.black.opacity(0.10))

                EnvelopeBottomCreases()
                    .stroke(
                        Color(red: 0.35, green: 0.18, blue: 0.02).opacity(0.45),
                        lineWidth: 0.9
                    )

                EnvelopeFlapShape()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color(red: 0.90, green: 0.70, blue: 0.26),
                                Color(red: 0.72, green: 0.50, blue: 0.14)
                            ]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: envelopeWidth, height: flapHeight)
                    .offset(y: flapOffset)
                    .rotation3DEffect(
                        .degrees(phase >= 2 ? 180 : 0),
                        axis: (x: 1, y: 0, z: 0),
                        anchor: .top
                    )

                if phase < 2 {
                    Text("\u{2764}\u{FE0F}")
                        .font(.system(size: 22))
                        .offset(y: sealOffsetY)
                }
            }
            .frame(width: envelopeWidth, height: envelopeHeight)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .frame(width: envelopeWidth, height: envelopeHeight)
    }
}

// MARK: - Envelope Fold Shapes

/// Bottom triangle: (0,H) → (W,H) → center  —  darkest fold (shadow)
struct EnvelopeBottomFold: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 0,           y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.midY))
        path.closeSubpath()
        return path
    }
}

/// Left side panel: top-left → bottom-left → center
struct EnvelopeLeftSideFold: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: 0,         y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.midY))
        path.closeSubpath()
        return path
    }
}

/// Right side panel: top-right → bottom-right → center
struct EnvelopeRightSideFold: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.maxX, y: 0))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.midY))
        path.closeSubpath()
        return path
    }
}

/// Only the two bottom crease lines (visible below the closed flap)
struct EnvelopeBottomCreases: Shape {
    func path(in rect: CGRect) -> Path {
        let centerX = rect.midX
        let centerY = rect.midY
        var path = Path()
        path.move(to: CGPoint(x: 0,         y: rect.maxY)); path.addLine(to: CGPoint(x: centerX, y: centerY))
        path.move(to: CGPoint(x: rect.maxX, y: rect.maxY)); path.addLine(to: CGPoint(x: centerX, y: centerY))
        return path
    }
}

// MARK: - Envelope Flap Shape

/// Triangle pointing DOWN: base spans full top edge, peak at bottom-center.
struct EnvelopeFlapShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 0,           y: 0))
        path.addLine(to: CGPoint(x: rect.maxX, y: 0))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

// MARK: - Dashed Divider

struct DashedDivider: View {
    var body: some View {
        GeometryReader { geometry in
            Path { path in
                path.move(to: CGPoint(x: 0, y: 0))
                path.addLine(to: CGPoint(x: geometry.size.width, y: 0))
            }
            .stroke(style: StrokeStyle(lineWidth: 1, dash: [6, 4]))
            .foregroundColor(
                Color(red: 0.85, green: 0.65, blue: 0.20).opacity(0.5)
            )
        }
    }
}
