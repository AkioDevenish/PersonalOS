import SwiftUI

/// Where you are in the cycle, and the one thing you might have opened the app
/// to write down.
///
/// A ring rather than a calendar grid. A cycle is the one thing this app
/// measures that genuinely is a circle, and thirty coloured squares answer
/// "which dates" when the question people actually have is "where am I".
struct CycleView: View {
    @StateObject private var store = CycleStore()
    @State private var logging = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Kicker(text: "The cycle", color: Theme.accent, size: 11)
                    .padding(.top, 8)
                    .flowIn(0)

                if store.loading {
                    Composing(lines: 3)
                        .frame(height: 72)
                        .padding(.top, 26)
                } else if store.denied {
                    refused
                } else {
                    body(for: store.reading)
                }

                Ornament()
                    .padding(.top, 44)
                    .padding(.bottom, 30)
            }
            .padding(.horizontal, 24)
        }
        .compactsTabBar()
        .background(Theme.background)
        .navigationBarTitleDisplayMode(.inline)
        .task { await store.load() }
        .sheet(isPresented: $logging) {
            CycleLogSheet(today: store.reading.bleedingToday) { flow in
                if let flow {
                    await store.log(flow)
                } else {
                    await store.remove(on: Date())
                    await store.refresh()
                }
            }
        }
    }

    // MARK: The page

    @ViewBuilder
    private func body(for reading: Cycle.Reading) -> some View {
        if let day = reading.day {
            Text("Day \(day)")
                .font(Theme.serif(46))
                .foregroundStyle(Theme.text)
                .contentTransition(.numericText())
                .padding(.top, 14)
                .flowIn(1)

            if let phase = reading.phase {
                Text(phase.title)
                    .font(Theme.sans(11, medium: true))
                    .tracking(1.8)
                    .textCase(.uppercase)
                    .foregroundStyle(Theme.accent)
                    .padding(.top, 6)
                    .flowIn(1)

                Text(phase.note)
                    .font(Theme.serifBody(17))
                    .foregroundStyle(Theme.secondaryText)
                    .lineSpacing(6)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 14)
                    .flowIn(2)
            }

            CycleRing(reading: reading)
                .frame(height: 210)
                .frame(maxWidth: .infinity)
                .padding(.top, 30)
                .flowIn(3)

            Text(expectation(reading))
                .font(Theme.sans(12.5))
                .foregroundStyle(Theme.secondaryText)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 26)
                .flowIn(4)
        } else {
            Text("Nothing written yet.")
                .font(Theme.serif(34))
                .foregroundStyle(Theme.text)
                .padding(.top, 14)
                .flowIn(1)

            Text("Record the first day of a period and this page starts counting. After two cycles it can say when to expect the next one; before that it would only be repeating the one month it has seen.")
                .font(Theme.serifBody(17))
                .foregroundStyle(Theme.secondaryText)
                .lineSpacing(6)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 14)
                .flowIn(2)
        }

        logButton
            .padding(.top, 30)
            .flowIn(5)

        if !reading.periods.isEmpty {
            SectionRule(text: "Recorded")
                .padding(.top, 40)
                .flowIn(6)

            VStack(spacing: 0) {
                ForEach(reading.periods.prefix(6)) { period in
                    periodRow(period, typical: reading.typicalLength)
                }
            }
            .padding(.top, 6)
            .flowIn(6)
        }

        privacy
            .padding(.top, 40)
            .flowIn(7)
    }

    /// What the counting can and cannot say.
    private func expectation(_ reading: Cycle.Reading) -> String {
        guard reading.canPredict, let length = reading.typicalLength else {
            return "One more cycle and this can start expecting the next one. Counting from a single previous cycle is a guess wearing a date."
        }
        guard let away = reading.daysAway else { return "" }
        let cycle = "Your cycles have been running about \(length) days."
        if away > 1 { return "\(cycle) The next one is expected in \(away) days." }
        if away == 1 { return "\(cycle) The next one is expected tomorrow." }
        if away == 0 { return "\(cycle) The next one is expected today." }
        return "\(cycle) The next one was expected \(abs(away)) \(abs(away) == 1 ? "day" : "days") ago. Cycles move, and a late one is usually just a late one."
    }

    private func periodRow(_ period: Cycle.Period, typical: Int?) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(period.start.formatted(.dateTime.day().month(.wide)))
                .font(Theme.serif(18))
                .foregroundStyle(Theme.text)
            Spacer(minLength: 8)
            Text("\(period.days) \(period.days == 1 ? "day" : "days")")
                .font(Theme.sans(11))
                .foregroundStyle(Theme.tertiaryText)
        }
        .padding(.vertical, 13)
        .overlay(alignment: .bottom) { Rule() }
    }

    private var logButton: some View {
        Button {
            Haptics.tap()
            logging = true
        } label: {
            Text(store.reading.bleedingToday == nil ? "Write today down" : "Change today")
                .font(Theme.sans(15, medium: true))
                .foregroundStyle(Theme.surface)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Theme.text, in: Capsule())
        }
        .buttonStyle(.press)
    }

    private var refused: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Health access is needed.")
                .font(Theme.serif(30))
                .foregroundStyle(Theme.text)
            Text("This page reads and writes only one thing, your period, and it asks separately from the rest of the app so that permission is its own decision. Open Settings, then Health, then Data Access, to change it.")
                .font(Theme.serifBody(17))
                .foregroundStyle(Theme.secondaryText)
                .lineSpacing(6)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 20)
    }

    /// Said on the page rather than buried in a policy, because it is the
    /// reason to use this one rather than a better-funded one.
    private var privacy: some View {
        VStack(alignment: .leading, spacing: 8) {
            Kicker(text: "Where this lives", size: 9)
            Text("On this phone, in Apple Health, and nowhere else. Cycle records are never sent to Personal OS's servers and are never included in the readings you can hand to a practitioner — not by policy, but because the sync and the sharing sheet are both built from a daily snapshot this data is deliberately kept out of.")
                .font(Theme.sans(11.5))
                .foregroundStyle(Theme.tertiaryText)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// The cycle as a ring, with today on it.
///
/// Drawn rather than assembled from shapes so the ticks can be struck at the
/// weight of an engraving: one hairline per day, the bleeding days heavier,
/// and today the only thing in amber.
private struct CycleRing: View {
    let reading: Cycle.Reading

    var body: some View {
        Canvas { context, size in
            let length = reading.typicalLength ?? 28
            let bleed = reading.typicalPeriodDays ?? 5
            let day = reading.day ?? 1
            let centre = CGPoint(x: size.width / 2, y: size.height / 2)
            let radius = min(size.width, size.height) / 2 - 24

            for index in 0..<length {
                // Twelve o'clock is day one, so the ring reads like a face.
                let angle = (Double(index) / Double(length)) * 2 * .pi - .pi / 2
                let isBleeding = index < bleed
                let isToday = index == (day - 1) % length
                let inner = radius - (isToday ? 16 : (isBleeding ? 10 : 6))

                var line = Path()
                line.move(to: point(centre, radius, angle))
                line.addLine(to: point(centre, inner, angle))
                context.stroke(
                    line,
                    with: .color(isToday ? Theme.accent : Theme.text.opacity(isBleeding ? 0.42 : 0.16)),
                    lineWidth: isToday ? 2.4 : 1
                )
            }

            context.stroke(
                Path(ellipseIn: CGRect(
                    x: centre.x - radius, y: centre.y - radius,
                    width: radius * 2, height: radius * 2
                )),
                with: .color(Theme.text.opacity(0.08)),
                lineWidth: 1
            )
        }
        .overlay {
            if let phase = reading.phase {
                Text(phase.title.lowercased())
                    .font(Theme.serifItalic(17))
                    .foregroundStyle(Theme.tertiaryText)
            }
        }
        .accessibilityLabel(
            reading.day.map { "Day \($0) of about \(reading.typicalLength ?? 28)" } ?? "No cycle recorded"
        )
    }

    private func point(_ centre: CGPoint, _ r: CGFloat, _ angle: Double) -> CGPoint {
        CGPoint(x: centre.x + cos(angle) * r, y: centre.y + sin(angle) * r)
    }
}

/// Writing today down.
private struct CycleLogSheet: View {
    let today: Cycle.Flow?
    let save: (Cycle.Flow?) async -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var saving = false

    private let choices: [Cycle.Flow] = [.light, .medium, .heavy, .unspecified, .none]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("Today")
                    .font(Theme.serif(32))
                    .foregroundStyle(Theme.text)

                Text("Recorded in Apple Health, where the watch can use it and where you can delete it without asking us.")
                    .font(Theme.sans(12))
                    .foregroundStyle(Theme.secondaryText)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 10)

                VStack(spacing: 0) {
                    ForEach(choices, id: \.self) { flow in
                        Button {
                            Haptics.select()
                            Task {
                                saving = true
                                await save(flow)
                                saving = false
                                dismiss()
                            }
                        } label: {
                            HStack {
                                Text(flow == .unspecified ? "Bleeding, unspecified" : flow.label)
                                    .font(Theme.serif(20))
                                    .foregroundStyle(Theme.text)
                                Spacer()
                                if today == flow {
                                    Text("❧").font(Theme.serif(14)).foregroundStyle(Theme.accent)
                                }
                            }
                            .padding(.vertical, 16)
                            .contentShape(Rectangle())
                            .overlay(alignment: .bottom) { Rule() }
                        }
                        .buttonStyle(.pressRow)
                        .disabled(saving)
                    }
                }
                .padding(.top, 24)

                if today != nil {
                    Button {
                        Haptics.tap()
                        Task {
                            saving = true
                            await save(nil)
                            saving = false
                            dismiss()
                        }
                    } label: {
                        Kicker(text: "Take today back out", size: 10)
                    }
                    .buttonStyle(.press)
                    .disabled(saving)
                    .padding(.top, 26)
                }
            }
            .padding(.horizontal, 26)
            .padding(.top, 28)
            .padding(.bottom, 40)
        }
        .background(Theme.background)
        .presentationDetents([.medium])
    }
}
