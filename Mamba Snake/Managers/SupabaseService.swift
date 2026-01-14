import Combine
import Foundation
import SwiftUI

class SupabaseService: ObservableObject {
    static let shared = SupabaseService()

    // MARK: - CONFIGURATION
    // ⚠️ LÜTFEN BURAYI DOLDURUN / PLEASE FILL JS HERE
    // Supabase Proje URL'niz (Settings -> API -> Project URL)
    private let projectURL = "https://sxcnsthvkgbkciduxugy.supabase.co"
    // Supabase Anon Key (Settings -> API -> Project API keys -> anon public)
    private let apiKey =
        "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InN4Y25zdGh2a2dia2NpZHV4dWd5Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjgzODIzNzcsImV4cCI6MjA4Mzk1ODM3N30.8-4wu75FZRNhyXz9mkQj8g6GV2pMiyTlUsS5glW961A"

    // Table Name
    private let tableName = "scores"

    private init() {}

    // MARK: - API Calls

    /// En yüksek 5 skoru getirir
    func fetchTopScores() async throws -> [ScoreEntry] {
        guard
            let url = URL(
                string: "\(projectURL)/rest/v1/\(tableName)?select=*&order=score.desc&limit=10")
        else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        addHeaders(to: &request)

        let (data, _) = try await URLSession.shared.data(for: request)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        if let jsonString = String(data: data, encoding: .utf8) {
            print("Raw JSON Response: \(jsonString)")
        }

        return try decoder.decode([ScoreEntry].self, from: data)
    }

    /// Kullanıcının kendi en yüksek skorunu getirir
    func fetchUserBest(nickname: String) async throws -> ScoreEntry? {
        // Nickname'e göre filtrele, skora göre sırala, ilkini al
        let query = "nickname=eq.\(nickname)&order=score.desc&limit=1"
        guard let url = URL(string: "\(projectURL)/rest/v1/\(tableName)?select=*&\(query)") else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        addHeaders(to: &request)

        let (data, _) = try await URLSession.shared.data(for: request)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let results = try decoder.decode([ScoreEntry].self, from: data)
        return results.first
    }

    /// Yeni skor gönderir
    /// Yeni skor gönderir veya mevcut en yüksek skoru günceller
    func submitScore(nickname: String, score: Int, level: Int) async throws {
        // 1. Önce bu kullanıcının mevcut kaydı var mı kontrol et
        if let existingBest = try? await fetchUserBest(nickname: nickname) {
            // Kayıt var. Yeni skor daha yüksekse güncelle.
            if score > existingBest.score {
                print("New high score! Updating existing entry.")
                try await updateScore(id: existingBest.id!, newScore: score, newLevel: level)
            } else {
                print("Score is not higher than existing best. Skipping.")
            }
        } else {
            // Kayıt yok. Yeni oluştur.
            print("No existing entry found. Creating new score.")
            try await postNewScore(nickname: nickname, score: score, level: level)
        }
    }

    private func postNewScore(nickname: String, score: Int, level: Int) async throws {
        guard let url = URL(string: "\(projectURL)/rest/v1/\(tableName)") else {
            throw URLError(.badURL)
        }

        let newScore = ScoreEntry(
            id: nil, nickname: nickname, score: score, level: level, date: nil)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        addHeaders(to: &request)
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("return=representation", forHTTPHeaderField: "Prefer")

        let encoder = JSONEncoder()
        request.httpBody = try encoder.encode(newScore)

        let (_, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
            (200...299).contains(httpResponse.statusCode)
        else {
            throw URLError(.badServerResponse)
        }
    }

    private func updateScore(id: Int, newScore: Int, newLevel: Int) async throws {
        // id'ye göre güncelle
        let query = "id=eq.\(id)"
        guard let url = URL(string: "\(projectURL)/rest/v1/\(tableName)?\(query)") else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        addHeaders(to: &request)
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = ["score": newScore, "level": newLevel]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (_, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
            (200...299).contains(httpResponse.statusCode)
        else {
            throw URLError(.badServerResponse)
        }
    }

    /// Eski nickname'e sahip tüm skorları yeni nickname ile günceller
    func updateNickname(oldName: String, newName: String) async throws {
        // query: nickname=eq.oldName
        // body: { "nickname": "newName" }
        // method: PATCH

        let query = "nickname=eq.\(oldName)"
        guard let url = URL(string: "\(projectURL)/rest/v1/\(tableName)?\(query)") else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        addHeaders(to: &request)
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = ["nickname": newName]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (_, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
            (200...299).contains(httpResponse.statusCode)
        else {
            throw URLError(.badServerResponse)
        }
    }

    // MARK: - Helpers

    private func addHeaders(to request: inout URLRequest) {
        request.addValue(apiKey, forHTTPHeaderField: "apikey")
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
    }
}
