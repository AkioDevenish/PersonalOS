import Combine
import Foundation

/// One conversation with Pitchfork, kept so it can be picked up again later.
struct SavedChat: Codable, Identifiable, Hashable {
    let id: UUID
    var lines: [ChatLine]
    var updated: Date

    /// The first thing they asked, on one line and cut short, to tell chats apart in the list.
    var title: String {
        let first = lines.first { $0.who == .you }?.text ?? "Chat"
        let line = first.split(whereSeparator: \.isNewline).joined(separator: " ")
        return line.count > 60 ? String(line.prefix(60)).trimmingCharacters(in: .whitespaces) + "…" : line
    }
}

/// Past conversations, kept on the phone that had them, like the chats themselves.
@MainActor
final class Chats: ObservableObject {
    static let shared = Chats()

    /// Newest first.
    @Published private(set) var all: [SavedChat] = []

    /// Enough to look back over, few enough that the file stays small.
    private let keep = 50

    private let file: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base.appendingPathComponent("chats.json")
    }()

    private init() {
        if let data = try? Data(contentsOf: file),
           let decoded = try? JSONDecoder().decode([SavedChat].self, from: data) {
            all = decoded
        }
    }

    /// Saves the chat, moving it to the top of the list.
    func save(_ chat: SavedChat) {
        guard !chat.lines.isEmpty else { return }
        all.removeAll { $0.id == chat.id }
        all.insert(chat, at: 0)
        if all.count > keep { all = Array(all.prefix(keep)) }
        write()
    }

    func remove(_ chat: SavedChat) {
        all.removeAll { $0.id == chat.id }
        write()
    }

    /// Everything, for when the account these belonged to is gone.
    func removeAll() {
        all = []
        try? FileManager.default.removeItem(at: file)
    }

    private func write() {
        guard let data = try? JSONEncoder().encode(all) else { return }
        try? data.write(to: file, options: [.atomic, .completeFileProtection])
    }
}
