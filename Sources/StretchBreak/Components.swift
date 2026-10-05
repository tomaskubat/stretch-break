import StretchBreakCore
import SwiftUI

enum Palette {
    static let accent = Color.accentColor
    static let background = Color(nsColor: .windowBackgroundColor)
    static let card = Color(nsColor: .controlBackgroundColor)
    static let border = Color.primary.opacity(0.09)
}

struct OutcomeLabel: View {
    let outcome: BreakOutcome
    var usesColor = true
    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: symbol)
                .symbolRenderingMode(.monochrome)
                .foregroundStyle(usesColor && outcome == .completed ? Color.green : Color.secondary)
                .accessibilityHidden(true)
            Text(outcome.rawValue)
                .foregroundStyle(usesColor ? (outcome == .completed ? Color.green : Color.secondary) : Color.primary)
        }
        .font(.system(size: 11, weight: .medium))
        .accessibilityElement(children: .combine)
    }

    private var symbol: String {
        switch outcome {
        case .completed: "checkmark.circle.fill"
        case .partial: "circle.lefthalf.filled"
        case .skipped: "arrow.forward.circle"
        }
    }
}

struct SectionHeading: View {
    let title: String
    let subtitle: String
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title).font(.system(size: 20, weight: .semibold))
            Text(subtitle).font(.callout).foregroundStyle(.secondary)
        }
    }
}

extension View {
    func cardStyle() -> some View {
        background(Palette.card, in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Palette.border))
    }
}

struct StorageErrorBanner: View {
    let store: BreakEngine
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Your change could not be saved", systemImage: "exclamationmark.triangle")
                .font(.system(size: 12, weight: .semibold))
            Text("Previous results are safe. Retry before making another change.")
                .font(.system(size: 11)).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                Button("Retry saving") { store.retrySaving() }
                Text(store.persistenceError ?? "").font(.system(size: 10)).foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(12).frame(maxWidth: .infinity, alignment: .leading).cardStyle()
        .accessibilityIdentifier("storage-error")
    }
}
