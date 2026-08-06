import SwiftUI

/// The screen you open in the morning: date, briefing, the ledger.
struct HealthView: View {
    @EnvironmentObject var health: HealthKitManager
    @State private var snapshot: HealthSnapshot?
    @State private var loadFailed = false
    @State private var appeared = false

    private var dateKicker: String {
        let f = DateFormatter()
        f.dateFormat = "EEEE · MMMM d"
        return f.string(from: Date())
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 10) {
                    Kicker(text: dateKicker, color: Theme.amber, size: 11)
                    if let mood = snapshot?.stateOfMindLabels, !mood.isEmpty {
                        Text(mood)
                            .font(Theme.sans(10))
                            .tracking(1.2)
                            .foregroundStyle(Theme.mid)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 4)
                            .overlay(Capsule().stroke(Theme.hairline, lineWidth: 1))
                    }
                }
                .padding(.top, 8)

                Text("The day so far.")
                    .font(Theme.serif(34))
                    .foregroundStyle(Theme.ink)
                    .padding(.top, 8)

                NavigationLink {
                    BriefingView(snapshot: snapshot)
                } label: {
                    Plate {
                        VStack(alignment: .leading, spacing: 10) {
                            Kicker(text: "Morning briefing", size: 9.5)
                            Text(Briefing.compose(from: snapshot).summary)
                                .font(Theme.serifBody(19))
                                .foregroundStyle(Theme.ink)
                                .lineSpacing(6)
                                .multilineTextAlignment(.leading)
                            Text("READ THE FULL BRIEFING  →")
                                .font(Theme.sans(10, medium: true))
                                .tracking(1.8)
                                .foregroundStyle(Theme.amber)
                        }
                    }
                }
                .buttonStyle(.plain)
                .padding(.top, 22)

                SectionRule(text: "Consult")
                    .padding(.top, 30)

                // One ruled list rather than a grid of plates. Boxes inside
                // boxes fought the hairline vocabulary the rest of the app uses,
                // and a rule between rows says "list" without drawing four more
                // edges to do it.
                VStack(spacing: 0) {
                    Rule()
                    consultRow("Trends", "Steps, sleep, heart rate over time") { TrendsView() }
                    Rule()
                    consultRow("Correlations", "Does one metric follow another?") { CorrelationView() }
                    Rule()
                    consultRow("Nutrition", "What to eat next") { NutritionView() }
                    Rule()
                    consultRow("Specialists", "Read by an expert") { ExpertsView() }
                    Rule()
                }
                .padding(.top, 16)

                ForEach(Metrics.populatedGroups(snapshot), id: \.self) { group in
                    SectionRule(text: group.rawValue)
                        .padding(.top, 30)
                    grid(for: group)
                        .padding(.top, 16)
                }

                if snapshot != nil && Metrics.populatedGroups(snapshot).isEmpty {
                    Text("Nothing recorded yet today.")
                        .font(Theme.sans(12))
                        .foregroundStyle(Theme.dust)
                        .padding(.top, 26)
                }

                Spacer(minLength: 24)
            }
            .padding(.horizontal, 24)
        }
        .background(Theme.linen)
        .task { await load() }
        .refreshable { await load() }
    }

    /// Driven by the catalogue, so a metric added there appears here.
    ///
    /// No plates. The warm-white cards put a lighter rectangle behind every
    /// figure, which on a linen ground read as a box floating on paper rather
    /// than a number written on it — and fifteen of them turned the screen
    /// into a grid of tiles. The numbers now sit directly on the ground with a
    /// hairline under each, the same mark the rest of the app uses.
    private func grid(for group: MetricSpec.Group) -> some View {
        let columns = [GridItem(.flexible(), spacing: 18), GridItem(.flexible(), spacing: 18)]
        let specs = Metrics.inGroup(group).filter { snapshot.flatMap($0.value) != nil }
        return LazyVGrid(columns: columns, spacing: 20) {
            ForEach(Array(specs.enumerated()), id: \.element.id) { index, m in
                MetricTile(spec: m, snapshot: snapshot, index: index, appeared: appeared)
            }
        }
    }

    /// A door to one of the engines, in the ledger's list idiom.
    private func consultRow<D: View>(
        _ title: String,
        _ subtitle: String,
        @ViewBuilder destination: @escaping () -> D
    ) -> some View {
        NavigationLink { destination() } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(Theme.serif(19))
                        .foregroundStyle(Theme.ink)
                    Text(subtitle)
                        .font(Theme.sans(10.5))
                        .foregroundStyle(Theme.dust)
                }
                Spacer()
                Text("›").font(Theme.serif(18)).foregroundStyle(Theme.dust)
            }
            .padding(.vertical, 15)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func load() async {
        do {
            try await health.requestAuthorization()
            snapshot = try await health.fetchTodaySnapshot()
        } catch {
            loadFailed = true
        }
        // Drives the glyph stagger. Set after the read so the icons animate in
        // alongside their numbers rather than over an empty grid.
        withAnimation(.easeOut(duration: 0.3)) { appeared = true }
    }

    static func grouped(_ v: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        return f.string(from: NSNumber(value: Int(v.rounded()))) ?? "\(Int(v))"
    }

    static func duration(_ hours: Double) -> String {
        let mins = Int((hours * 60).rounded())
        return "\(mins / 60)h \(mins % 60)m"
    }
}
