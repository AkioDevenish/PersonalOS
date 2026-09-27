import SwiftUI

/// Where you are in the cycle, and the one thing you might have opened the app to write down.
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

            PhaseCarousel(reading: reading)
                .padding(.top, 26)
                .padding(.horizontal, -24)
                .flowIn(2)

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

            Text("Log the first day of your period to start. After two cycles it can predict the next one.")
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
            return "One more cycle and this can predict the next one."
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
            Text("This page needs access to your period data. Change it in Settings → Health → Data Access.")
                .font(Theme.serifBody(17))
                .foregroundStyle(Theme.secondaryText)
                .lineSpacing(6)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 20)
    }

    /// Said on the page rather than buried in a policy, because it is the reason to use this one
    /// rather than a better-funded one.
    private var privacy: some View {
        VStack(alignment: .leading, spacing: 8) {
            Kicker(text: "Where this lives", size: 9)
            Text("On this phone, in Apple Health, and nowhere else. Never sent to our servers or shared with practitioners.")
                .font(Theme.sans(11.5))
                .foregroundStyle(Theme.tertiaryText)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// The four phases, one to a page, opening on the one you are in.
private struct PhaseCarousel: View {
    let reading: Cycle.Reading

    @State private var shown: Cycle.Phase?

    private var length: Int { reading.typicalLength ?? 28 }
    private var bleed: Int { reading.typicalPeriodDays ?? 5 }

    var body: some View {
        VStack(spacing: 18) {
            ScrollView(.horizontal) {
                HStack(spacing: 0) {
                    ForEach(Cycle.Phase.allCases, id: \.self) { phase in
                        card(phase)
                            .containerRelativeFrame(.horizontal)
                            .id(phase)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollIndicators(.hidden)
            .scrollTargetBehavior(.paging)
            .scrollPosition(id: $shown)

            HStack(spacing: 22) {
                ForEach(Cycle.Phase.allCases, id: \.self) { phase in
                    Button {
                        Haptics.select()
                        withAnimation(Theme.Motion.flow) { shown = phase }
                    } label: {
                        Image(systemName: phase.symbol)
                            .font(.system(size: 16))
                            .foregroundStyle((shown ?? current) == phase ? phase.tint : Theme.tertiaryText)
                            .frame(width: 36, height: 36)
                            .background {
                                if phase == reading.phase {
                                    Circle().stroke(phase.tint.opacity(0.6), lineWidth: 1.5)
                                }
                            }
                            .scaleEffect((shown ?? current) == phase ? 1.15 : 1)
                    }
                    .buttonStyle(.press)
                    .accessibilityLabel(phase.title)
                }
            }
            .animation(Theme.Motion.bouncy, value: shown)
        }
        .onAppear { shown = current }
    }

    /// Where to open: the phase you are in, or the start of a cycle when that is not known yet.
    private var current: Cycle.Phase { reading.phase ?? .menstrual }

    private func card(_ phase: Cycle.Phase) -> some View {
        let here = phase == reading.phase
        return VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(phase.tint.opacity(0.14))
                    .frame(width: 150, height: 150)
                if here {
                    Circle()
                        .stroke(phase.tint, lineWidth: 2)
                        .frame(width: 166, height: 166)
                }
                Image(systemName: phase.symbol)
                    .font(.system(size: 58, weight: .regular))
                    .foregroundStyle(phase.tint)
                    .symbolEffect(.bounce, value: shown == phase)
            }
            .frame(height: 172)

            if here, let day = reading.day {
                Text("YOU'RE HERE · DAY \(day)")
                    .font(Theme.sans(11, medium: true))
                    .tracking(1.4)
                    .foregroundStyle(phase.tint)
            } else {
                Text(" ").font(Theme.sans(11))
            }

            Text(phase.title)
                .font(Theme.serif(30))
                .foregroundStyle(Theme.text)

            if let days = phase.days(in: length, bleedingFor: bleed) {
                Text(days.count == 1 ? "Day \(days.lowerBound)" : "Days \(days.lowerBound) to \(days.upperBound)")
                    .font(Theme.sans(13, medium: true))
                    .foregroundStyle(Theme.secondaryText)
            }

            Text(phase.note)
                .font(Theme.serifBody(16))
                .foregroundStyle(Theme.secondaryText)
                .multilineTextAlignment(.center)
                .lineSpacing(5)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 30)
        }
        .frame(maxWidth: .infinity)
    }
}

private extension Cycle.Phase {
    /// Held in both light and dark: mid-tones that read on white and on black.
    var tint: Color {
        switch self {
        case .menstrual: return Color(red: 0.78, green: 0.29, blue: 0.36)
        case .follicular: return Color(red: 0.36, green: 0.62, blue: 0.42)
        case .ovulatory: return Color(red: 0.85, green: 0.60, blue: 0.18)
        case .luteal: return Color(red: 0.40, green: 0.42, blue: 0.78)
        }
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

                Text("Saved in Apple Health.")
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
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundStyle(Theme.accent)
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
