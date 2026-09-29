import SwiftUI

/// Where you cook and eat.
enum Cuisine {
    /// The stored country code, or empty for no preference.
    static let key = "meal_country"

    struct Country: Identifiable, Hashable {
        let code: String
        let name: String
        var id: String { code }
    }

    /// Every country the system knows, named in the reader's own language.
    static let all: [Country] = {
        Locale.Region.isoRegions
            .filter { region in
                region.subRegions.isEmpty
                    && region.identifier.count == 2
                    && region.identifier.allSatisfy(\.isLetter)
            }
            .compactMap { region in
                guard let name = Locale.current.localizedString(forRegionCode: region.identifier)
                else { return nil }
                return Country(code: region.identifier, name: name)
            }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }()

    /// The phone already knows where it is, so the useful default is there rather than at "no
    /// preference" — someone in Port of Spain shouldn't have to tell the app twice.
    static var deviceDefault: String {
        Locale.current.region?.identifier ?? ""
    }

    static func name(for code: String) -> String {
        guard !code.isEmpty else { return "Anywhere" }
        return Locale.current.localizedString(forRegionCode: code) ?? code
    }
}

/// Picking the country, in the ledger's list idiom.
struct CountryPicker: View {
    @Binding var code: String
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    private var matches: [Cuisine.Country] {
        guard !query.isEmpty else { return Cuisine.all }
        return Cuisine.all.filter { $0.name.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if query.isEmpty {
                        row(name: "Anywhere", marked: code.isEmpty) { pick("") }
                    }

                    ForEach(matches) { country in
                        row(name: country.name, marked: country.code == code) {
                            pick(country.code)
                        }
                    }

                    if matches.isEmpty {
                        Text("No country by that name.")
                            .font(Theme.sans(12))
                            .foregroundStyle(Theme.tertiaryText)
                            .padding(.top, 24)
                    }

                    Spacer(minLength: 30)
                }
                .padding(.horizontal, 24)
            }
            .appBackground()
            .navigationTitle("Where you eat")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $query, prompt: "Country")
        }
    }

    private func pick(_ new: String) {
        Haptics.select()
        code = new
        dismiss()
    }

    private func row(name: String, marked: Bool, tap: @escaping () -> Void) -> some View {
        Button(action: tap) {
            HStack {
                Text(name)
                    .font(Theme.serif(18))
                    .foregroundStyle(marked ? Theme.accent : Theme.text)
                Spacer()
                if marked { SelectionMark() }
            }
            .padding(.vertical, 13)
            .contentShape(Rectangle())
        }
        .buttonStyle(.pressRow)
    }
}
