import Combine
import FirebaseDatabase
import FirebaseFirestore
import Foundation

@MainActor
final class MultiplayerService: ObservableObject {
    static let shared = MultiplayerService()

    @Published private(set) var status: MultiplayerRoomStatus = .idle
    @Published private(set) var role: MultiplayerRole?
    @Published private(set) var roomCode = ""
    @Published private(set) var opponentNickname = ""
    @Published private(set) var remoteDirection: Direction = .none
    // Render döngüsünün okuduğu mailbox. @Published olursa her 50 ms snapshot
    // bütün SwiftUI oyun arayüzünü yeniden hesaplatır ve guest FPS'ini düşürür.
    private(set) var latestSnapshot: MultiplayerGameSnapshot?
    @Published var errorMessage: String?

    var isHost: Bool { role == .host }
    var isGuest: Bool { role == .guest }

    private var roomListener: ListenerRegistration?
    private var roomReference: DocumentReference?
    private var userID = ""

    // Canlı oyun verisi: düşük gecikme için Realtime Database
    private let realtimeDatabase = Database.database(
        url: "https://mamba-snake-4532c-default-rtdb.europe-west1.firebasedatabase.app")
    private var liveRoomReference: DatabaseReference?
    private var stateHandle: DatabaseHandle?
    private var gridHandle: DatabaseHandle?
    private var inputHandle: DatabaseHandle?
    private var latestLiveMotion: [String: Any] = [:]
    private var latestLiveGridRevision = -1
    private var latestLiveFilledCells: [Int] = []
    private var latestLiveTrailCells: [Int] = []

    private init() {
        // Bağlantı kopmalarında hızlı toparlanma ve yerel önbellek
        realtimeDatabase.isPersistenceEnabled = false
    }

    func createRoom(nickname: String) async {
        await leaveRoom()
        guard FirebaseFeatureService.shared.multiplayerEnabled else {
            fail(with: MultiplayerError.multiplayerUnavailable)
            return
        }
        status = .creating
        errorMessage = nil

        do {
            let sanitizedNickname = PlayerNickname.sanitize(nickname)
            guard !sanitizedNickname.isEmpty else {
                throw MultiplayerError.invalidNickname
            }

            let currentUserID = try await FirebaseService.shared.authenticatedUserID()
            let database = try FirebaseService.shared.database()
            let code = try await availableRoomCode(in: database)
            let reference = database.collection("rooms").document(code)

            try await reference.setData([
                "hostID": currentUserID,
                "hostNickname": sanitizedNickname,
                "hostDirection": Direction.none.rawValue,
                "guestDirection": Direction.none.rawValue,
                "status": MultiplayerRoomStatus.waiting.rawValue,
                "createdAt": FieldValue.serverTimestamp(),
                "updatedAt": FieldValue.serverTimestamp(),
            ])

            userID = currentUserID
            role = .host
            roomCode = code
            roomReference = reference
            status = .waiting
            attachLiveRoom(code: code, asHost: true, userID: currentUserID)
            listen(to: reference)
            FirebaseTelemetryService.shared.logMultiplayerRoom(action: "created")
        } catch {
            fail(with: error)
        }
    }

    func joinRoom(code: String, nickname: String) async {
        await leaveRoom()
        guard FirebaseFeatureService.shared.multiplayerEnabled else {
            fail(with: MultiplayerError.multiplayerUnavailable)
            return
        }
        status = .joining
        errorMessage = nil

        do {
            let sanitizedNickname = PlayerNickname.sanitize(nickname)
            guard !sanitizedNickname.isEmpty else {
                throw MultiplayerError.invalidNickname
            }

            let normalizedCode = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
            guard normalizedCode.count == 6 else {
                throw MultiplayerError.invalidRoomCode
            }

            let currentUserID = try await FirebaseService.shared.authenticatedUserID()
            let database = try FirebaseService.shared.database()
            let reference = database.collection("rooms").document(normalizedCode)

            _ = try await database.runTransaction { transaction, errorPointer -> Any? in
                let document: DocumentSnapshot
                do {
                    document = try transaction.getDocument(reference)
                } catch {
                    errorPointer?.pointee = error as NSError
                    return nil
                }

                guard let values = document.data() else {
                    errorPointer?.pointee = MultiplayerError.roomNotFound as NSError
                    return nil
                }
                guard values["hostID"] as? String != currentUserID else {
                    errorPointer?.pointee = MultiplayerError.cannotJoinOwnRoom as NSError
                    return nil
                }
                guard values["status"] as? String == MultiplayerRoomStatus.waiting.rawValue,
                    values["guestID"] == nil
                else {
                    errorPointer?.pointee = MultiplayerError.roomIsFull as NSError
                    return nil
                }

                transaction.updateData([
                    "guestID": currentUserID,
                    "guestNickname": sanitizedNickname,
                    "guestDirection": Direction.none.rawValue,
                    "status": MultiplayerRoomStatus.playing.rawValue,
                    "updatedAt": FieldValue.serverTimestamp(),
                ], forDocument: reference)
                return nil
            }

            userID = currentUserID
            role = .guest
            roomCode = normalizedCode
            roomReference = reference
            status = .playing
            attachLiveRoom(code: normalizedCode, asHost: false, userID: currentUserID)
            listen(to: reference)
            FirebaseTelemetryService.shared.logMultiplayerRoom(action: "joined")
        } catch {
            fail(with: error)
        }
    }

    /// RTDB canlı oda bağlantısını kurar: meta kaydı, dinleyiciler ve
    /// kopuşta otomatik temizlik (onDisconnect).
    private func attachLiveRoom(code: String, asHost: Bool, userID: String) {
        let liveRoom = realtimeDatabase.reference(withPath: "rooms/\(code)")
        liveRoomReference = liveRoom

        if asHost {
            liveRoom.child("meta").setValue(["hostID": userID])
            // Host koparsa oda verisi geride kalmasın
            liveRoom.onDisconnectRemoveValue()

            // Misafir yön girdisini anında al
            inputHandle = liveRoom.child("input/direction").observe(.value) { [weak self] data in
                Task { @MainActor in
                    guard let self, let raw = data.value as? String,
                        let direction = Direction(rawValue: raw)
                    else { return }
                    self.remoteDirection = direction
                }
            }
        } else {
            liveRoom.child("meta/guestID").setValue(userID)
            liveRoom.child("meta/guestID").onDisconnectRemoveValue()

            // Küçük hareket paketini yüksek frekansta al. Grid dizileri bu
            // callback'e dahil değildir; ilerleyen bölümlerde ana thread'i yormaz.
            stateHandle = liveRoom.child("state/motion").observe(.value) { [weak self] data in
                Task { @MainActor in
                    guard let self, let values = data.value as? [String: Any] else { return }
                    self.applyLiveMotion(values)
                }
            }
            // Büyük hücre listeleri yalnız grid gerçekten değiştiğinde gelir.
            gridHandle = liveRoom.child("state/grid").observe(.value) { [weak self] data in
                Task { @MainActor in
                    guard let self, let values = data.value as? [String: Any] else { return }
                    self.applyLiveGrid(values)
                }
            }
        }
    }

    func sendDirection(_ direction: Direction) {
        guard isGuest, let liveRoomReference else { return }
        // RTDB yazımı yerelde anında yankılanır; ağ gidişini beklemeye gerek yok
        liveRoomReference.child("input/direction").setValue(direction.rawValue) { _, _ in }
    }

    func publish(
        sequence: Int,
        gridRevision: Int,
        hostPosition: CGPoint,
        hostDirection: Direction,
        guestPosition: CGPoint,
        guestDirection: Direction,
        snakePosition: CGPoint,
        snakeBodyPositions: [CGPoint],
        score: Int,
        lives: Int,
        level: Int,
        percentCovered: Float,
        gameState: GameState,
        filledCells: [Int]?,
        trailCells: [Int]?
    ) async -> Bool {
        guard isHost, let liveRoomReference else { return false }

        let motionValues: [String: Any] = [
            "sequence": sequence,
            "hostX": Double(hostPosition.x),
            "hostY": Double(hostPosition.y),
            "hostDirection": hostDirection.rawValue,
            "guestX": Double(guestPosition.x),
            "guestY": Double(guestPosition.y),
            "authoritativeGuestDirection": guestDirection.rawValue,
            "snakeX": Double(snakePosition.x),
            "snakeY": Double(snakePosition.y),
            "snakeBodyX": snakeBodyPositions.map { Double($0.x) },
            "snakeBodyY": snakeBodyPositions.map { Double($0.y) },
            "score": score,
            "lives": lives,
            "level": level,
            "percentCovered": Double(percentCovered),
            "gameState": gameState.rawValue,
        ]
        // Hareket paketi küçüktür ve 20 Hz gönderilir.
        liveRoomReference.child("state/motion").setValue(motionValues) { _, _ in }

        if let filledCells, let trailCells {
            let gridValues: [String: Any] = [
                "revision": gridRevision,
                "filledCells": filledCells,
                "trailCells": trailCells,
            ]
            liveRoomReference.child("state/grid").setValue(gridValues) { _, _ in }
        }
        return true
    }

    func leaveRoom() async {
        roomListener?.remove()
        roomListener = nil
        detachLiveRoom(removeData: isHost)

        if let roomReference, role != nil {
            do {
                if isHost {
                    try await roomReference.updateData([
                        "status": MultiplayerRoomStatus.closed.rawValue,
                        "updatedAt": FieldValue.serverTimestamp(),
                    ])
                } else {
                    try await roomReference.updateData([
                        "guestID": FieldValue.delete(),
                        "guestNickname": FieldValue.delete(),
                        "guestDirection": Direction.none.rawValue,
                        "status": MultiplayerRoomStatus.waiting.rawValue,
                        "updatedAt": FieldValue.serverTimestamp(),
                    ])
                }
            } catch {
                print("Failed to leave multiplayer room: \(error)")
            }
        }

        resetLocalState()
        errorMessage = nil
    }

    func endSessionAfterOpponentLeft(message: String) async {
        if isHost {
            await leaveRoom()
        } else {
            roomListener?.remove()
            roomListener = nil
            detachLiveRoom(removeData: false)
            resetLocalState()
        }
        errorMessage = message
    }

    private func detachLiveRoom(removeData: Bool) {
        if let liveRoomReference {
            if let stateHandle {
                liveRoomReference.child("state/motion").removeObserver(withHandle: stateHandle)
            }
            if let gridHandle {
                liveRoomReference.child("state/grid").removeObserver(withHandle: gridHandle)
            }
            if let inputHandle {
                liveRoomReference.child("input/direction").removeObserver(withHandle: inputHandle)
            }
            liveRoomReference.cancelDisconnectOperations()
            if removeData {
                liveRoomReference.removeValue()
            } else if isGuest {
                liveRoomReference.child("meta/guestID").removeValue()
            }
        }
        stateHandle = nil
        gridHandle = nil
        inputHandle = nil
        liveRoomReference = nil
    }

    private func applyLiveMotion(_ values: [String: Any]) {
        latestLiveMotion = values
        assembleLiveSnapshot()
    }

    private func applyLiveGrid(_ values: [String: Any]) {
        latestLiveGridRevision = integer("revision", in: values)
        latestLiveFilledCells = integerArray("filledCells", in: values)
        latestLiveTrailCells = integerArray("trailCells", in: values)
        assembleLiveSnapshot()
    }

    /// Ayrı gelen motion ve grid kanallarını tek render snapshot'ında birleştirir.
    private func assembleLiveSnapshot() {
        let values = latestLiveMotion
        guard value("hostX", in: values) != nil,
            value("guestX", in: values) != nil,
            value("snakeX", in: values) != nil
        else { return }

        latestSnapshot = MultiplayerGameSnapshot(
            sequence: integer("sequence", in: values),
            gridRevision: latestLiveGridRevision,
            hostX: value("hostX", in: values) ?? 0,
            hostY: value("hostY", in: values) ?? 0,
            hostDirection: Direction(rawValue: values["hostDirection"] as? String ?? "") ?? .none,
            guestX: value("guestX", in: values) ?? 0,
            guestY: value("guestY", in: values) ?? 0,
            guestDirection: Direction(
                rawValue: values["authoritativeGuestDirection"] as? String ?? "") ?? .none,
            snakeX: value("snakeX", in: values) ?? 0,
            snakeY: value("snakeY", in: values) ?? 0,
            snakeBody: points(
                xValues: numberArray("snakeBodyX", in: values),
                yValues: numberArray("snakeBodyY", in: values)),
            score: integer("score", in: values),
            lives: integer("lives", in: values),
            level: max(1, integer("level", in: values)),
            percentCovered: Float(value("percentCovered", in: values) ?? 0),
            gameState: GameState(rawValue: values["gameState"] as? String ?? "") ?? .ready,
            filledCells: latestLiveFilledCells,
            trailCells: latestLiveTrailCells
        )
    }

    private func listen(to reference: DocumentReference) {
        roomListener?.remove()
        roomListener = reference.addSnapshotListener { [weak self] document, error in
            Task { @MainActor in
                guard let self else { return }
                if let error {
                    self.fail(with: error)
                    return
                }
                guard let values = document?.data() else {
                    self.fail(with: MultiplayerError.roomClosed)
                    return
                }
                self.applyRoom(values)
            }
        }
    }

    private func applyRoom(_ values: [String: Any]) {
        if let rawStatus = values["status"] as? String,
            let roomStatus = MultiplayerRoomStatus(rawValue: rawStatus)
        {
            status = roomStatus
        }

        if isHost {
            opponentNickname = values["guestNickname"] as? String ?? ""
        } else {
            opponentNickname = values["hostNickname"] as? String ?? ""
        }
    }

    private func availableRoomCode(in database: Firestore) async throws -> String {
        for _ in 0..<8 {
            let code = String((0..<6).compactMap { _ in "ABCDEFGHJKLMNPQRSTUVWXYZ23456789".randomElement() })
            let document = try await database.collection("rooms").document(code).getDocument()
            if !document.exists { return code }
        }
        throw MultiplayerError.couldNotCreateRoom
    }

    private func value(_ key: String, in values: [String: Any]) -> Double? {
        (values[key] as? NSNumber)?.doubleValue
    }

    private func integer(_ key: String, in values: [String: Any]) -> Int {
        (values[key] as? NSNumber)?.intValue ?? 0
    }

    private func numberArray(_ key: String, in values: [String: Any]) -> [NSNumber] {
        (values[key] as? [Any] ?? []).compactMap { $0 as? NSNumber }
    }

    private func integerArray(_ key: String, in values: [String: Any]) -> [Int] {
        numberArray(key, in: values).map(\.intValue)
    }

    private func points(xValues: [NSNumber], yValues: [NSNumber]) -> [CGPoint] {
        zip(xValues, yValues).map {
            CGPoint(x: $0.doubleValue, y: $1.doubleValue)
        }
    }

    private func fail(with error: Error) {
        FirebaseTelemetryService.shared.record(error, operation: "multiplayer_room")
        errorMessage = error.localizedDescription
        status = .idle
    }

    private func resetLocalState() {
        status = .idle
        role = nil
        roomCode = ""
        opponentNickname = ""
        remoteDirection = .none
        latestSnapshot = nil
        roomReference = nil
        liveRoomReference = nil
        latestLiveMotion = [:]
        latestLiveGridRevision = -1
        latestLiveFilledCells = []
        latestLiveTrailCells = []
        userID = ""
    }
}

enum MultiplayerError: LocalizedError {
    case multiplayerUnavailable
    case invalidNickname
    case invalidRoomCode
    case roomNotFound
    case roomIsFull
    case cannotJoinOwnRoom
    case couldNotCreateRoom
    case roomClosed

    var errorDescription: String? {
        switch self {
        case .multiplayerUnavailable: return "Online co-op is temporarily unavailable."
        case .invalidNickname: return "Nickname must contain between 1 and 24 characters."
        case .invalidRoomCode: return "Room code must contain 6 characters."
        case .roomNotFound: return "Room not found."
        case .roomIsFull: return "This room is already full or the game has started."
        case .cannotJoinOwnRoom: return "You cannot join your own room."
        case .couldNotCreateRoom: return "A unique room code could not be created."
        case .roomClosed: return "The host closed the room."
        }
    }
}