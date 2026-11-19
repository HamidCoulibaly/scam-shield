import SwiftUI

struct HomeView: View {
    @Environment(SecurityModel.self) private var model

    private var headline: String {
        switch model.score {
        case 0.85...: return "Well protected"
        case 0.5..<0.85: return "Getting there"
        default: return "Let's lock things down"
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    scoreCard
                    if let next = model.nextStep {
                        NavigationLink(value: next.area.id) { nextStepCard(next.area, next.item) }
                            .buttonStyle(.plain)
                    }
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)],
                              spacing: 12) {
                        ForEach(Catalog.areas) { area in
                            NavigationLink(value: area.id) { AreaTile(area: area) }
                                .buttonStyle(.plain)
                        }
                    }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Scam Shield")
            .navigationDestination(for: String.self) { id in AreaDetailView(areaID: id) }
            .refreshable { await model.refresh() }
            .toolbar {
                if model.checking { ProgressView() }
            }
        }
    }

    private var scoreCard: some View {
        Card {
            HStack(spacing: 20) {
                ScoreRing(progress: model.score).frame(width: 120, height: 120)
                VStack(alignment: .leading, spacing: 6) {
                    Text(headline).font(.title3.bold())
                    Text("\(model.goodCount) of \(model.allItems.count) protections in place")
                        .font(.subheadline).foregroundStyle(.secondary)
                    if let checked = model.lastChecked {
                        Text("Checked \(checked.formatted(.relative(presentation: .named)))")
                            .font(.caption).foregroundStyle(.tertiary)
                    }
                }
            }
        }
    }

    private func nextStepCard(_ area: SetupArea, _ item: SetupItem) -> some View {
        Card {
            HStack(spacing: 14) {
                Image(systemName: area.symbol)
                    .font(.title2)
                    .foregroundStyle(.white)
                    .frame(width: 48, height: 48)
                    .background(area.tint.gradient, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                VStack(alignment: .leading, spacing: 3) {
                    Text("NEXT STEP").font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
                    Text(item.title).font(.headline)
                    Text(item.why).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").foregroundStyle(.tertiary)
            }
        }
    }
}

struct AreaTile: View {
    @Environment(SecurityModel.self) private var model
    let area: SetupArea

    var body: some View {
        let p = model.progress(area)
        let worst = area.items.map { model.status($0) }.worst
        Card {
            HStack {
                Image(systemName: area.symbol).font(.title2).foregroundStyle(area.tint)
                Spacer()
                Image(systemName: worst == .good ? "checkmark.seal.fill" : worst.symbol)
                    .foregroundStyle(worst == .good ? Color.green : worst.color)
            }
            Text(area.title).font(.headline)
            ProgressView(value: Double(p.done), total: Double(max(p.total, 1))).tint(area.tint)
            Text("\(p.done) of \(p.total) done").font(.caption).foregroundStyle(.secondary)
        }
    }
}
