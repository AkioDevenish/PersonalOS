import SwiftUI

/// What you're aiming at.
///
/// This was every metric the app can measure, each with a text field, which
/// meant a decimal keypad and a dozen decisions to set one goal. A goal is a
/// rare thing to set and an easy thing to fumble — a thumb that misses on a
/// keypad asks for eighty thousand steps — so nothing here is typed.
///
/// What is on screen is what you have chosen, and nothing else. Adding one is
/// a list of what is left, then a single number under your thumb.
struct GoalsView: View {
    @State private var targets: [String: Double] = [:]
    @State private var adding = false
    @State private var editing: MetricSpec?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("Goals")
                    .font(Theme.serif(32))
                    .foregroundStyle(Theme.text)
                    .padding(.top, 10)
                    .flowIn(0)

                Text(chosen.isEmpty
                     ? "Nothing yet. Set one and the day's briefing closes with it whenever it hasn't been met."
                     : "The briefing closes with whichever of these the day hasn't met.")
                    .font(Theme.serifBody(17))
                    .foregroundStyle(Theme.secondaryText)
                    .lineSpacing(5)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 10)
                    .flowIn(1)

                VStack(spacing: 0) {
                    ForEach(chosen) { spec in
                        Button { editing = spec } label: { row(spec) }
                            .buttonStyle(.pressRow)
                    }
                }
                .padding(.top, 26)
                .flowIn(2)

                if !unset.isEmpty {
                    Button { adding = true } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "plus")
                                .font(.system(size: 14, weight: .medium))
                            Text(chosen.isEmpty ? "Set your first goal" : "Add a goal")
                        }
                        .font(Theme.sans(15, medium: true))
                        .foregroundStyle(Theme.background)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(Theme.text, in: Capsule())
                    }
                    .buttonStyle(.press)
                    .padding(.top, chosen.isEmpty ? 30 : 34)
                    .flowIn(3)
                }

                Ornament()
                    .padding(.top, 44)
                    .padding(.bottom, 26)
            }
            .padding(.horizontal, 24)
        }
        .compactsTabBar()
        .background(Theme.background)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { targets = Goals.all }
        .sheet(isPresented: $adding) {
            GoalPicker(specs: unset) { spec in
                adding = false
                // A beat, so the two sheets do not fight over the screen.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { editing = spec }
            }
        }
        .sheet(item: $editing) { spec in
            GoalEditor(spec: spec, current: targets[spec.id]) {
                targets = Goals.all
            }
        }
    }

    private var chosen: [MetricSpec] {
        Goals.settable.filter { targets[$0.id] != nil }
    }

    private var unset: [MetricSpec] {
        Goals.settable.filter { targets[$0.id] == nil }
    }

    /// One goal: what it is, which way it points, and the number.
    private func row(_ spec: MetricSpec) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                Text(spec.label)
                    .font(Theme.serif(20))
                    .foregroundStyle(Theme.text)
                // "At least" or "at most" is the whole meaning of the number
                // beside it, and not something to infer from which metric it is.
                Text(spec.goal == .atMost ? "AT MOST" : "AT LEAST")
                    .font(Theme.sans(9, medium: true))
                    .tracking(1.4)
                    .foregroundStyle(Theme.tertiaryText)
            }
            Spacer(minLength: 8)
            Text(targets[spec.id].map { Goals.editable(spec, $0) } ?? "")
                .font(Theme.serif(26))
                .foregroundStyle(Theme.text)
                .contentTransition(.numericText())
            if !spec.unit.isEmpty {
                Text(spec.unit)
                    .font(Theme.sans(11))
                    .foregroundStyle(Theme.tertiaryText)
            }
        }
        .padding(.vertical, 16)
        .contentShape(Rectangle())
        .overlay(alignment: .bottom) { Rule() }
    }
}

/// Which goal to set, from what is left.
private struct GoalPicker: View {
    let specs: [MetricSpec]
    let pick: (MetricSpec) -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(specs) { spec in
                        Button { pick(spec) } label: {
                            HStack(spacing: 14) {
                                Image(systemName: spec.symbol)
                                    .font(.system(size: 17, weight: .light))
                                    .environment(\.symbolVariants, .none)
                                    .foregroundStyle(Theme.accent)
                                    .frame(width: 26)
                                Text(spec.label)
                                    .font(Theme.serif(19))
                                    .foregroundStyle(Theme.text)
                                Spacer()
                                if let suggested = Goals.suggestion(for: spec) {
                                    Text(Goals.editable(spec, suggested))
                                        .font(Theme.sans(13))
                                        .foregroundStyle(Theme.tertiaryText)
                                }
                            }
                            .padding(.vertical, 15)
                            .contentShape(Rectangle())
                            .overlay(alignment: .bottom) { Rule() }
                        }
                        .buttonStyle(.pressRow)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 8)
            }
            .background(Theme.background)
            .navigationTitle("What to aim at")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium, .large])
    }
}

/// One number, under a thumb.
private struct GoalEditor: View {
    let spec: MetricSpec
    let current: Double?
    let done: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var value: Double = 0

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Text(spec.goal == .atMost ? "AT MOST" : "AT LEAST")
                    .font(Theme.sans(9, medium: true))
                    .tracking(1.6)
                    .foregroundStyle(Theme.tertiaryText)
                    .padding(.top, 26)

                HStack(alignment: .center, spacing: 26) {
                    stepButton("minus") { move(-1) }

                    VStack(spacing: 2) {
                        Text(Goals.editable(spec, value))
                            .font(Theme.serif(56))
                            .foregroundStyle(Theme.text)
                            .contentTransition(.numericText())
                            .monospacedDigit()
                        if !spec.unit.isEmpty {
                            Text(spec.unit)
                                .font(Theme.sans(12))
                                .foregroundStyle(Theme.tertiaryText)
                        }
                    }
                    .frame(minWidth: 150)

                    stepButton("plus") { move(1) }
                }
                .padding(.top, 14)

                if let suggested = Goals.suggestion(for: spec) {
                    Button {
                        withAnimation(Theme.Motion.flow) { value = suggested }
                    } label: {
                        Text("Suggested · \(Goals.editable(spec, suggested))\(spec.unit.isEmpty ? "" : " \(spec.unit)")")
                            .font(Theme.sans(13))
                            .foregroundStyle(Theme.accent)
                    }
                    .buttonStyle(.press)
                    .padding(.top, 22)
                }

                Spacer(minLength: 20)

                Button {
                    Goals.set(spec.id, value)
                    Haptics.tap()
                    done()
                    dismiss()
                } label: {
                    Text(current == nil ? "Set this goal" : "Save")
                        .font(Theme.sans(16, medium: true))
                        .foregroundStyle(Theme.background)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(Theme.text, in: Capsule())
                }
                .buttonStyle(.press)

                if current != nil {
                    Button {
                        Goals.set(spec.id, nil)
                        done()
                        dismiss()
                    } label: {
                        Text("Remove this goal")
                            .font(Theme.sans(14))
                            .foregroundStyle(Theme.secondaryText)
                    }
                    .buttonStyle(.press)
                    .padding(.top, 16)
                }
            }
            .padding(.horizontal, 26)
            .padding(.bottom, 26)
            .background(Theme.background)
            .navigationTitle(spec.label)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } }
            }
        }
        .presentationDetents([.medium])
        .onAppear {
            value = current ?? Goals.suggestion(for: spec) ?? Goals.step(for: spec) * 10
        }
    }

    private func move(_ direction: Double) {
        let range = Goals.range(for: spec)
        let next = value + Goals.step(for: spec) * direction
        guard range.contains(next) else { return }
        Haptics.select()
        withAnimation(Theme.Motion.flow) { value = next }
    }

    private func stepButton(_ symbol: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(Theme.text)
                .frame(width: 52, height: 52)
                .background(Theme.surface, in: Circle())
        }
        .buttonStyle(.press)
        .accessibilityLabel(symbol == "plus" ? "Increase" : "Decrease")
    }
}
