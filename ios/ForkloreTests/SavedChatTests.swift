import Foundation
import Testing
@testable import Forklore

/// Saved chats have to come back exactly as they were, and read well in the list.
@MainActor
struct SavedChatTests {
    @Test func survivesBeingWrittenAndReadBack() throws {
        let chat = SavedChat(
            id: UUID(),
            lines: [
                ChatLine(who: .you, text: "What should I cook tonight?"),
                ChatLine(
                    who: .assistant, text: "Try a pelau.",
                    steps: [ThinkingStep(symbol: "sparkles", label: "Writing a reply")], seconds: 3
                ),
            ],
            updated: Date(timeIntervalSince1970: 1_000_000)
        )
        let data = try JSONEncoder().encode(chat)
        let back = try JSONDecoder().decode(SavedChat.self, from: data)
        #expect(back == chat)
    }

    @Test func titleIsTheFirstQuestionOnOneLine() {
        let chat = SavedChat(
            id: UUID(),
            lines: [ChatLine(who: .you, text: "From a photo:\nFlour, sugar, eggs")],
            updated: Date()
        )
        #expect(chat.title == "From a photo: Flour, sugar, eggs")
    }

    @Test func longTitlesAreCutShort() {
        let chat = SavedChat(
            id: UUID(),
            lines: [ChatLine(who: .you, text: String(repeating: "a", count: 100))],
            updated: Date()
        )
        #expect(chat.title == String(repeating: "a", count: 60) + "…")
    }
}
