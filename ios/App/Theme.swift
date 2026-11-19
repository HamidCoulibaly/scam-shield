import SwiftUI

extension Color {
    static let shieldAccent = Color(red: 0.16, green: 0.76, blue: 0.62)   // teal-green
    static let shieldDeep = Color(red: 0.07, green: 0.29, blue: 0.47)     // deep blue
}

/// Traffic-light status used everywhere in the app.
enum Status: Equatable {
    case good, warn, bad, todo, unknown

    var color: Color {
        switch self {
        case .good: return .green
        case .warn: return .orange
        case .bad: return .red
        case .todo: return .secondary
        case .unknown: return .secondary
        }
    }

    var symbol: String {
        switch self {
        case .good: return "checkmark.circle.fill"
        case .warn: return "exclamationmark.circle.fill"
        case .bad: return "xmark.circle.fill"
        case .todo: return "circle"
        case .unknown: return "questionmark.circle"
        }
    }

    /// Higher = worse. Used to roll several results into one.
    var severity: Int {
        switch self {
        case .good: return 0
        case .todo: return 1
        case .unknown: return 2
        case .warn: return 3
        case .bad: return 4
        }
    }
}

extension Array where Element == Status {
    var worst: Status { self.max(by: { $0.severity < $1.severity }) ?? .unknown }
}

struct Card<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) { content }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemGroupedBackground),
                        in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

struct ScoreRing: View {
    let progress: Double

    var body: some View {
        ZStack {
            Circle().stroke(Color.secondary.opacity(0.2), lineWidth: 14)
            Circle()
                .trim(from: 0, to: max(0.001, progress))
                .stroke(AngularGradient(colors: [.shieldAccent, .shieldDeep, .shieldAccent], center: .center),
                        style: StrokeStyle(lineWidth: 14, lineCap: .round))
                .rotationEffect(.degrees(-90))
            VStack(spacing: 0) {
                Text("\(Int((progress * 100).rounded()))")
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .contentTransition(.numericText())
                Text("score").font(.caption).foregroundStyle(.secondary)
            }
        }
        .animation(.spring(duration: 0.8), value: progress)
    }
}

struct StatusIcon: View {
    let status: Status
    var body: some View {
        Image(systemName: status.symbol)
            .font(.title3)
            .foregroundStyle(status.color)
            .frame(width: 28)
    }
}

struct StatTile: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 2) {
            Text(value).font(.title2.weight(.bold)).monospacedDigit()
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(Color(.tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}
