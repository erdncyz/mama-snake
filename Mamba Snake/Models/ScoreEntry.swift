import Foundation

enum LeaderboardCategory: String, CaseIterable, Identifiable {
    case solo
    case multiplayer

    var id: String { rawValue }

    var title: String {
        switch self {
        case .solo: return "SOLO"
        case .multiplayer: return "CO-OP"
        }
    }
}

struct ScoreEntry: Identifiable {
    var id: String?
    let nickname: String
    let teammateNickname: String?
    let score: Int
    let level: Int
    let date: Date?

    init(
        id: String?,
        nickname: String,
        teammateNickname: String? = nil,
        score: Int,
        level: Int,
        date: Date?
    ) {
        self.id = id
        self.nickname = nickname
        self.teammateNickname = teammateNickname
        self.score = score
        self.level = level
        self.date = date
    }
}
