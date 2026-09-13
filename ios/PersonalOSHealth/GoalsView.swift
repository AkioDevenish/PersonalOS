import SwiftUI

/// Setting them.
struct GoalsView: View {
    @State private var values: [String: String] = [:]
    @FocusState private var editing: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Kicker(text: "Goals", color: Theme.amber, size: 11)
                    .padding(.top, 12)
                    .flowIn(0)

                Text("What you're aiming at.")
                    .font(Theme.serif(32))
                    .foregroundStyle(Theme.ink)
                    .padding(.top, 8)
                    .flowIn(1)

                Text("Set as many or as few as you like. The morning briefing closes with whichever ones the day hasn't met yet, so an empty list here means it stops telling you what to do.")
                    .font(Theme.serifBody(17))
                    .foregroundStyle(Theme.mid)
                    .lineSpacing(5)
                    .padding(.top, 10)
                    .flowIn(2)

                ForEach(Array(groups.enumerated()), id: \.element.group) { i, section in
                    SectionRule(text: section.group.rawValue)
                        .padding(.top, i == 0 ? 34 : 30)
                        .flowIn(3 + i)

                    VStack(spacing: 0) {
                        ForEach(section.specs) { spec in
                            row(spec)
                        }
                    }
                    .padding(.top, 8)
                    .flowIn(3 + i)
                }

                Spacer(minLength: 40)
            }
            .padding(.horizontal, 24)
        }
        .background(Theme.linen)
        .toolbarBackground(Theme.linen, for: .navigationBar)
        .onAppear(perform: read)
    }

    private var groups: [(group: MetricSpec.Group, specs: [MetricSpec])] {
        MetricSpec.Group.allCases.compactMap { group in
            let specs = Goals.settable.filter { $0.group == group }
            return specs.isEmpty ? nil : (group, specs)
        }
    }

    private func row(_ spec: MetricSpec) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(spec.label)
                    .font(Theme.serif(19))
                    .foregroundStyle(Theme.ink)
                // "At least" or "at most" is the whole meaning of the number
                // beside it, and it is not something a person should have to
                // infer from which metric it is.
                Text(spec.goal == .atMost ? "at most" : "at least")
                    .font(Theme.sans(10))
                    .foregroundStyle(Theme.dust)
            }

            Spacer()

            TextField(placeholder(spec), text: binding(for: spec))
                .font(Theme.serif(22))
                .foregroundStyle(Theme.ink)
                .multilineTextAlignment(.trailing)
                .keyboardType(.decimalPad)
                .focused($editing, equals: spec.id)
                .frame(maxWidth: 110)
                .onChange(of: values[spec.id] ?? "") { _, new in
                    // Only an empty field clears a goal. A string that will
                    // not parse is a half-typed number, not an instruction to
                    // forget the target.
                    if new.trimmingCharacters(in: .whitespaces).isEmpty {
                        Goals.set(spec.id, nil)
                    } else if let parsed = Goals.number(from: new) {
                        Goals.set(spec.id, parsed)
                    }
                }

            if !spec.unit.isEmpty {
                Text(spec.unit)
                    .font(Theme.sans(10))
                    .foregroundStyle(Theme.dust)
                    .frame(width: 34, alignment: .leading)
            } else {
                Color.clear.frame(width: 34, height: 1)
            }
        }
        .padding(.vertical, 14)
        .contentShape(Rectangle())
        .onTapGesture { editing = spec.id }
    }

    private func placeholder(_ spec: MetricSpec) -> String {
        Goals.suggestion(for: spec).map { Goals.editable(spec, $0) } ?? "none"
    }

    private func binding(for spec: MetricSpec) -> Binding<String> {
        Binding(
            get: { values[spec.id] ?? "" },
            set: { values[spec.id] = $0 }
        )
    }

    private func read() {
        let stored = Goals.all
        values = Dictionary(uniqueKeysWithValues: Goals.settable.compactMap { spec in
            stored[spec.id].map { (spec.id, Goals.editable(spec, $0)) }
        })
    }
}
