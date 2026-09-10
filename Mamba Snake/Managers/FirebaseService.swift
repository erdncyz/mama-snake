import Combine
import FirebaseAuth
import FirebaseCore
import FirebaseFirestore
import Foundation

@MainActor
final class FirebaseService: ObservableObject {
    static let shared = FirebaseService()

    @Published private(set) var isConfigured = false
    @Published private(set) var configurationError: String?

    private let scoresCollection = "scores"

    private init() {}

    static func configure() {
        guard !shared.isConfigured else { return }

        guard let path = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
            let options = FirebaseOptions(contentsOfFile: path)
        else {
            shared.configurationError =
                "GoogleService-Info.plist is missing. Add your Firebase iOS configuration file to the Mamba Snake target."
            return
        }

        FirebaseApp.configure(options: options)
        shared.isConfigured = true
        shared.configurationError = nil
    }

    func fetchTopScores(limit: Int = 10) async throws -> [ScoreEntry] {
        _ = try await authenticatedUserID()

        let fetchLimit = max(100, min(500, limit * 10))
        let snapshot = try await database()
            .collection(scoresCollection)
            .order(by: "score", descending: true)
            .limit(to: fetchLimit)
            .getDocuments()

        var bestByNickname: [String: ScoreEntry] = [:]
        for document in snapshot.documents {
            guard let entry = scoreEntry(from: document) else { continue }
            let key = entry.nickname.folding(
                options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            if entry.score > (bestByNickname[key]?.score ?? -1) {
                bestByNickname[key] = entry
            }
        }

        return Array(bestByNickname.values.sorted { $0.score > $1.score }.prefix(limit))
    }

    func fetchUserBest(nickname _: String) async throws -> ScoreEntry? {
        let userID = try await authenticatedUserID()
        let document = try await database().collection(scoresCollection).document(userID)
            .getDocument()
        return scoreEntry(from: document)
    }

    func submitScore(nickname: String, score: Int, level: Int) async throws {
        let sanitizedNickname = PlayerNickname.sanitize(nickname)
        guard !sanitizedNickname.isEmpty else {
            throw FirebaseServiceError.invalidNickname
        }

        let userID = try await authenticatedUserID()
        let reference = try database().collection(scoresCollection).document(userID)
        let existing = try await reference.getDocument()

        if let currentScore = existing.data()?["score"] as? Int, currentScore >= score {
            return
        }

        var values: [String: Any] = [
            "nickname": sanitizedNickname,
            "nicknameNormalized": normalizedNickname(sanitizedNickname),
            "ownerID": userID,
            "score": score,
            "level": level,
            "updatedAt": FieldValue.serverTimestamp(),
        ]
        if !existing.exists {
            values["createdAt"] = FieldValue.serverTimestamp()
        }

        try await reference.setData(values, merge: true)
    }

    func updateNickname(oldName _: String, newName: String) async throws {
        let sanitizedNickname = PlayerNickname.sanitize(newName)
        guard !sanitizedNickname.isEmpty else {
            throw FirebaseServiceError.invalidNickname
        }

        let userID = try await authenticatedUserID()
        let reference = try database().collection(scoresCollection).document(userID)
        let existing = try await reference.getDocument()
        guard existing.exists else { return }

        try await reference.updateData([
            "nickname": sanitizedNickname,
            "nicknameNormalized": normalizedNickname(sanitizedNickname),
            "updatedAt": FieldValue.serverTimestamp(),
        ])
    }

    func authenticatedUserID() async throws -> String {
        guard isConfigured else {
            throw FirebaseServiceError.notConfigured(configurationError)
        }

        if let userID = Auth.auth().currentUser?.uid {
            return userID
        }

        return try await Auth.auth().signInAnonymously().user.uid
    }

    func database() throws -> Firestore {
        guard isConfigured else {
            throw FirebaseServiceError.notConfigured(configurationError)
        }
        return Firestore.firestore()
    }

    private func scoreEntry(from document: DocumentSnapshot) -> ScoreEntry? {
        guard let values = document.data(),
            let nickname = values["nickname"] as? String,
            let score = values["score"] as? Int,
            let level = values["level"] as? Int
        else { return nil }

        let date = (values["updatedAt"] as? Timestamp)?.dateValue()
            ?? (values["createdAt"] as? Timestamp)?.dateValue()
        return ScoreEntry(
            id: document.documentID,
            nickname: nickname,
            score: score,
            level: level,
            date: date
        )
    }

    private func normalizedNickname(_ nickname: String) -> String {
        nickname.trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
    }
}

enum FirebaseServiceError: LocalizedError {
    case notConfigured(String?)
    case invalidNickname

    var errorDescription: String? {
        switch self {
        case .notConfigured(let reason):
            return reason ?? "Firebase is not configured."
        case .invalidNickname:
            return "Nickname must contain between 1 and 24 characters."
        }
    }
}
