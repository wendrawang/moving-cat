import SwiftUI

// MARK: - Demo Section Container

struct DemoSection<Content: View>: View {

    let title: String
    let content: () -> Content

    init(title: String, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title.uppercased())
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.secondary)

            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(UIColor.secondarySystemBackground))
        )
    }
}

// MARK: - Demo Row

struct DemoRow: View {

    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.system(.subheadline, design: .monospaced))
                .fontWeight(.medium)
        }
    }
}

// MARK: - Demo Button Label

struct DemoButtonLabel: View {

    let text: String
    var icon: String?
    let color: Color

    var body: some View {
        HStack(spacing: 6) {
            iconView
            Text(text)
                .font(.system(size: 16, weight: .semibold))
        }
        .foregroundColor(.white)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(color)
        )
    }

    private var iconView: some View {
        Group {
            if icon != nil {
                Image(systemName: icon ?? "circle")
                    .font(.system(size: 13))
            }
        }
    }
}
