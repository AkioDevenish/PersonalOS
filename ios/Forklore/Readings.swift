import Foundation
import Combine

/// Readings and meal suggestions, kept on the phone that wrote them.
struct Reading: Codable, Identifiable, Hashable {
    enum Kind: String, Codable { case report, meal }

    let id: UUID
    let kind: Kind
    /// Which lens wrote it, for a report.
    let expert: String?
    /// Which window it read, for a report.
    let period: String?
    let text: String
    let at: Date

    init(kind: Kind, expert: String? = nil, period: String? = nil, text: String, at: Date = Date()) {
        self.id = UUID()
        self.kind = kind
        self.expert = expert
        self.period = period
        self.text = text
        self.at = at
    }
}

@MainActor
final class Readings: ObservableObject {
    static let shared = Readings()

    @Published private(set) var all: [Reading] = []

    /// Enough to look back over, few enough that the file stays small.
    private let keep = 60

    private let file: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base.appendingPathComponent("readings.json")
    }()

    private init() {
        if let data = try? Data(contentsOf: file),
           let decoded = try? JSONDecoder().decode([Reading].self, from: data) {
            all = decoded
        }
    }

    func add(_ reading: Reading) {
        all.insert(reading, at: 0)
        if all.count > keep { all = Array(all.prefix(keep)) }
        save()
    }

    /// Everything, for when the account these belonged to is gone.
    func removeAll() {
        all = []
        try? FileManager.default.removeItem(at: file)
    }

    func remove(_ reading: Reading) {
        all.removeAll { $0.id == reading.id }
        save()
    }

    func of(_ kind: Reading.Kind) -> [Reading] {
        all.filter { $0.kind == kind }
    }

    /// Reports for one lens and window, newest first.
    func reports(expert: String, period: String) -> [Reading] {
        all.filter { $0.kind == .report && $0.expert == expert && $0.period == period }
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(all) else { return }
        try? data.write(to: file, options: .atomic)
    }
}
