import Foundation

struct ScoreEntry: Codable, Identifiable {
    var id: UUID?
    let nickname: String
    let score: Int
    let level: Int
    let date: Date?  // Maps to created_at

    enum CodingKeys: String, CodingKey {
        case id
        case nickname
        case score
        case level
        case date = "created_at"
    }
}
