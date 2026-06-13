import SwiftUI

// MARK: - Stress Gauge View

struct StressGaugeView: View {

    let stressPoints: Int

    private let gaugeSize: CGFloat = 200
    private let lineWidth: CGFloat = 14

    private var normalized: Double {
        min(Double(stressPoints) / Double(CatStressConstants.maxStress), 1.0)
    }

    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                gaugeTrack
                gaugeFill
                gaugeCenter
            }
            .frame(width: gaugeSize, height: gaugeSize / 2 + 24)

            stressWarning
        }
    }

    private var gaugeTrack: some View {
        HalfCircleArc()
            .stroke(
                Color.gray.opacity(0.15),
                style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
            )
            .frame(width: gaugeSize, height: gaugeSize / 2)
            .offset(y: -12)
    }

    private var gaugeFill: some View {
        HalfCircleArc()
            .trim(from: 0, to: CGFloat(normalized))
            .stroke(
                gaugeGradient,
                style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
            )
            .frame(width: gaugeSize, height: gaugeSize / 2)
            .offset(y: -12)
    }

    private var gaugeCenter: some View {
        VStack(spacing: 2) {
            Text("\(stressPoints)")
                .font(.system(size: 42, weight: .bold, design: .rounded))
                .foregroundColor(stressTierColor)

            Text(stressTierLabel)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(stressTierColor.opacity(0.8))

            Text("Stress Level")
                .font(.system(size: 10))
                .foregroundColor(.secondary)
        }
        .offset(y: 8)
    }

    private var stressWarning: some View {
        Group {
            if stressPoints >= CatStressConstants.voucherStressThreshold {
                Text("Stress sangat tinggi!")
                    .font(.caption)
                    .foregroundColor(.red)
                    .fontWeight(.medium)
            }
        }
    }

    private var gaugeGradient: AngularGradient {
        AngularGradient(
            gradient: Gradient(colors: [.green, .yellow, .orange, .red]),
            center: .center,
            startAngle: .degrees(180),
            endAngle: .degrees(360)
        )
    }

    private var stressTierLabel: String {
        switch stressPoints {
        case 0...30:  return "Sehat"
        case 31...60: return "Waspada"
        case 61...74: return "Kritis"
        case 75...89: return "Overload"
        default:      return "Voucher!"
        }
    }

    private var stressTierColor: Color {
        switch stressPoints {
        case 0...30:  return .green
        case 31...60: return .yellow
        case 61...74: return .orange
        case 75...89: return Color(red: 1.0, green: 0.4, blue: 0.0)
        default:      return .red
        }
    }
}

// MARK: - Half Circle Arc Shape

struct HalfCircleArc: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addArc(
            center: CGPoint(x: rect.midX, y: rect.maxY),
            radius: rect.width / 2,
            startAngle: .degrees(180),
            endAngle: .degrees(360),
            clockwise: false
        )
        return path
    }
}
