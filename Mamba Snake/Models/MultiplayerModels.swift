import Foundation

enum GameMode: String {
    case solo
    case multiplayer
}

enum MultiplayerRole: String {
    case host
    case guest
}

enum MultiplayerRoomStatus: String {
    case idle
    case creating
    case joining
    case waiting
    case playing
    case gameOver
    case levelComplete
    case closed
}

struct MultiplayerGameSnapshot {
    let sequence: Int
    let gridRevision: Int
    let hostX: Double
    let hostY: Double
    let hostDirection: Direction
    let guestX: Double
    let guestY: Double
    let guestDirection: Direction
    let snakeX: Double
    let snakeY: Double
    let snakeBody: [CGPoint]
    let hostTrail: [CGPoint]
    let guestTrail: [CGPoint]
    let score: Int
    let lives: Int
    let level: Int
    let percentCovered: Float
    let gameState: GameState
    let filledCells: [Int]
    let trailCells: [Int]
}