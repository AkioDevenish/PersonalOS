import SwiftUI

/// The briefing content, composed on-device from today's snapshot.
///
/// This is deliberately rule-based for now: honest sentences derived from
/// real numbers. When the server's AI reports move off SQLite, this struct
/// is the seam where they arrive — same shape, better prose.
struct Briefing {
    let headline: String
    let paragraphs: [String]
    let suggestions: [String]

    var summary: String { paragraphs.first ?? "Connect Apple Health to begin your ledger." }

    static func compose(from s: HealthSnapshot?) -> Briefing {
        guard let s else {
            return Briefing(
                headline: "The ledger is empty.",
                paragraphs: ["Allow Health access and today's entries will write themselves."],
                suggestions: ["Allow Health access from Settings"]
            )
        }
        var paras: [String] = []
        var sugg: [String] = []
        var headline = "The day, in ink."

        // zero total is "no samples", not a measured night
        if let sleep = s.totalSleepHours, sleep > 0 {
            let d = TodayView.duration(sleep)
            if sleep < 6.5 {
                headline = "A short night."
                var line = "You slept \(d) — on the short side."
                if let rhr = s.restingHeartRate {
                    line = "You slept \(d) — on the short side — but your resting heart rate held at \(Int(rhr.rounded()))."
                    headline = "A short night,\nsteady heart."
                }
                paras.append(line)
                sugg.append("Lights out earlier tonight to repay the hour")
            } else {
                headline = "A well-kept night."
                paras.append("You slept \(d), and the ledger opens in credit.")
            }
        }

        if let steps = s.steps {
            let n = TodayView.grouped(steps)
            if steps < 4000 {
                paras.append("Steps stand at \(n) so far — the day still owes you a walk.")
                sugg.append("An easy 30-minute walk, ideally in daylight")
            } else {
                paras.append("Steps stand at \(n) so far — the account is filling on its own.")
            }
        }

        if let energy = s.activeEnergyBurned {
            paras.append("Active energy so far: \(Int(energy.rounded())) kcal.")
        }

        if paras.isEmpty {
            paras.append("No entries yet today — the ledger fills as you move.")
        }
        if sugg.isEmpty {
            sugg.append("Nothing owed — spend the day as you like")
        }
        return Briefing(headline: headline, paragraphs: paras, suggestions: sugg)
    }
}

struct BriefingView: View {
    let snapshot: HealthSnapshot?

    private var dateLine: String {
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMMM d"
        return f.string(from: Date())
    }

    var body: some View {
        let b = Briefing.compose(from: snapshot)
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Kicker(text: "Morning briefing · \(dateLine)", color: Theme.amber)
                    .padding(.top, 12)

                Text(b.headline)
                    .font(Theme.serif(34))
                    .foregroundStyle(Theme.ink)
                    .lineSpacing(2)
                    .padding(.top, 10)

                ForEach(b.paragraphs, id: \.self) { p in
                    Text(p)
                        .font(Theme.serifBody(18))
                        .foregroundStyle(Theme.ink)
                        .lineSpacing(7)
                        .padding(.top, 16)
                }

                Ornament()
                    .padding(.vertical, 26)

                Kicker(text: "Spend today on")

                ForEach(Array(b.suggestions.enumerated()), id: \.offset) { i, s in
                    HStack(alignment: .firstTextBaseline, spacing: 14) {
                        Text(["I", "II", "III", "IV"][min(i, 3)])
                            .font(Theme.serif(17))
                            .foregroundStyle(Theme.amber)
                            .frame(width: 22, alignment: .leading)
                        Text(s)
                            .font(Theme.serifBody(17))
                            .foregroundStyle(Theme.mid)
                            .lineSpacing(5)
                    }
                    .padding(.top, 14)
                }

                Spacer(minLength: 40)
            }
            .padding(.horizontal, 24)
        }
        .background(Theme.linen)
        .toolbarBackground(Theme.linen, for: .navigationBar)
    }
}
