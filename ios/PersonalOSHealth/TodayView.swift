import SwiftUI

/// The screen you open in the morning: date, briefing, the ledger.
struct TodayView: View {
    @EnvironmentObject var health: HealthKitManager
    @State private var snapshot: HealthSnapshot?
    @State private var loadFailed = false

    private var dateKicker: String {
        let f = DateFormatter()
        f.dateFormat = "EEEE · MMMM d"
        return f.string(from: Date())
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Kicker(text: dateKicker, color: Theme.amber, size: 11)
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

                SectionRule(text: "The ledger")
                    .padding(.top, 28)

                metricGrid
                    .padding(.top, 18)

                Spacer(minLength: 24)
            }
            .padding(.horizontal, 24)
        }
        .background(Theme.linen)
        .task { await load() }
        .refreshable { await load() }
    }

    private var metricGrid: some View {
        let columns = [GridItem(.flexible(), spacing: 13), GridItem(.flexible(), spacing: 13)]
        return LazyVGrid(columns: columns, spacing: 13) {
            metric("Steps", snapshot?.steps.map { Self.grouped($0) })
            metric("Sleep", snapshot?.totalSleepHours.flatMap { $0 > 0 ? Self.duration($0) : nil })
            metric("Resting HR", snapshot?.restingHeartRate.map { String(Int($0.rounded())) })
            metric("Active energy", snapshot?.activeEnergyBurned.map { "\(Int($0.rounded())) kcal" })
        }
    }

    private func metric(_ label: String, _ value: String??) -> some View {
        Plate {
            VStack(alignment: .leading, spacing: 6) {
                Kicker(text: label, size: 9)
                Text((value ?? nil) ?? "—")
                    .font(Theme.serif(30))
                    .foregroundStyle(Theme.ink)
                Text((value ?? nil) == nil ? "no data yet" : "from Apple Health")
                    .font(Theme.sans(10))
                    .foregroundStyle(Theme.dust)
            }
        }
    }

    private func load() async {
        do {
            try await health.requestAuthorization()
            snapshot = try await health.fetchTodaySnapshot()
        } catch {
            loadFailed = true
        }
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
