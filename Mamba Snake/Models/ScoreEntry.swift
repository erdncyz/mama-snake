import Foundation

struct ScoreEntry: Identifiable {
    var id: String?
    let nickname: String
    let score: Int
    let level: Int
    let date: Date?

    init(
        id: String?,
        nickname: String,
        score: Int,
        level: Int,
        date: Date?
    ) {
        self.id = id
        self.nickname = nickname
        self.score = score
        self.level = level
        self.date = date
    }
}
