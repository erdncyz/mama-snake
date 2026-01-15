import Foundation

struct ScoreEntry: Codable, Identifiable {
    var id: String?  // UUID yerine String kullan (Supabase bazen farklı formatlar döndürebiliyor)
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
    
    // Custom decoder - date parsing hatalarını yakala
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // id - String olarak decode et (UUID, Int veya String olabilir)
        if let idString = try? container.decode(String.self, forKey: .id) {
            id = idString
        } else if let idInt = try? container.decode(Int.self, forKey: .id) {
            id = String(idInt)
        } else {
            id = nil
        }
        
        nickname = try container.decode(String.self, forKey: .nickname)
        score = try container.decode(Int.self, forKey: .score)
        level = try container.decode(Int.self, forKey: .level)
        
        // date - ISO8601 formatında olmayabilir, esnek decode et
        if let dateString = try? container.decode(String.self, forKey: .date) {
            // Önce standart ISO8601 dene
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let parsedDate = formatter.date(from: dateString) {
                date = parsedDate
            } else {
                // Fractional seconds olmadan dene
                formatter.formatOptions = [.withInternetDateTime]
                date = formatter.date(from: dateString)
            }
        } else {
            date = nil
        }
    }
    
    // Encoder için
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(id, forKey: .id)
        try container.encode(nickname, forKey: .nickname)
        try container.encode(score, forKey: .score)
        try container.encode(level, forKey: .level)
        try container.encodeIfPresent(date, forKey: .date)
    }
    
    // Normal init - yeni kayıt oluşturmak için
    init(id: String?, nickname: String, score: Int, level: Int, date: Date?) {
        self.id = id
        self.nickname = nickname
        self.score = score
        self.level = level
        self.date = date
    }
}
