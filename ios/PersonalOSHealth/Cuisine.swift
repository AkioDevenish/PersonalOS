import SwiftUI

/// Where you cook and eat.
///
/// A meal suggestion is only useful if you can actually buy the ingredients.
/// "Grilled halloumi with za'atar" is a fine answer and a useless one if the
/// nearest shop sells provision, saltfish and pigeon peas — and a model told
/// nothing about where you are will reach for the same handful of Californian
/// wellness food every time.
///
/// So the country is part of the request. It is a standing preference rather
/// than a per-meal choice, which is why it persists: you do not move house
/// between breakfast and lunch.
enum Cuisine {
    /// The stored country code, or empty for no preference.
    static let key = "meal_country"

    struct Country: Identifiable, Hashable {
        let code: String
        let name: String
        var id: String { code }
    }

    /// Every country the system knows, named in the reader's own language.
    ///
    /// Built from the system rather than typed out: a hand-written list is a
    /// list that is wrong about somewhere, and being wrong about a country is
    /// the kind of wrong people remember. Continents and groupings are dropped
    /// — they have sub-regions, and "Americas" is not a cuisine.
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

    /// The phone already knows where it is, so the useful default is there
    /// rather than at "no preference" — someone in Port of Spain shouldn't
    /// have to tell the app twice.
    static var deviceDefault: String {
        Locale.current.region?.identifier ?? ""
    }

    static func name(for code: String) -> String {
        guard !code.isEmpty else { return "Anywhere" }
        return Locale.current.localizedString(forRegionCode: code) ?? code
    }
}

/// Picking the country, in the ledger's list idiom.
///
/// Searchable, because two hundred rows is not a list you scroll — and the one
/// you want is usually the one you can already name.
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
                            .foregroundStyle(Theme.dust)
                            .padding(.top, 24)
                    }

                    Spacer(minLength: 30)
                }
                .padding(.horizontal, 24)
            }
            .background(Theme.linen)
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
                    .foregroundStyle(marked ? Theme.amber : Theme.ink)
                Spacer()
                if marked { SelectionMark() }
            }
            .padding(.vertical, 13)
            .contentShape(Rectangle())
        }
        .buttonStyle(.pressRow)
    }
}
