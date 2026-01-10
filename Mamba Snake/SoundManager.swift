import AVFoundation

class SoundManager {
    static let shared = SoundManager()
    private var engine: AVAudioEngine
    private var playerNode: AVAudioPlayerNode
    private var mixer: AVAudioMixerNode
    private var audioFormat: AVAudioFormat

    private init() {
        engine = AVAudioEngine()
        playerNode = AVAudioPlayerNode()
        mixer = engine.mainMixerNode

        // Define standard format: 44.1kHz, Mono (Float32)
        // This matches our generation logic and prevents mismatch crashes
        audioFormat = AVAudioFormat(standardFormatWithSampleRate: 44100.0, channels: 1)!

        // Attach and Connect using explicit format
        engine.attach(playerNode)
        engine.connect(playerNode, to: mixer, format: audioFormat)

        // Start Engine
        do {
            try engine.start()
        } catch {
            print("SoundManager: Engine start error: \(error)")
        }
    }

    // Helper to generate specific waveforms
    private func generateBuffer(freq: Float, duration: Double, type: String = "sine")
        -> AVAudioPCMBuffer?
    {
        let frameCount = AVAudioFrameCount(audioFormat.sampleRate * duration)

        guard let buffer = AVAudioPCMBuffer(pcmFormat: audioFormat, frameCapacity: frameCount)
        else { return nil }

        buffer.frameLength = frameCount
        let channels = buffer.floatChannelData

        var theta: Float = 0.0
        let theta_increment = 2.0 * Float.pi * freq / Float(audioFormat.sampleRate)

        for frame in 0..<Int(frameCount) {
            var value: Float = 0.0
            let time = Float(frame) / Float(audioFormat.sampleRate)

            // Envelope (Fade Out)
            let envelope = 1.0 - (time / Float(duration))

            switch type {
            case "square":
                value = (sin(theta) > 0 ? 0.5 : -0.5) * envelope
            case "sawtooth":
                value =
                    (theta.truncatingRemainder(dividingBy: 2.0 * Float.pi) / (2.0 * Float.pi) * 2.0
                        - 1.0) * 0.5 * envelope
            case "noise":
                value = Float.random(in: -0.5...0.5) * envelope
            default:  // Sine
                value = sin(theta) * 0.5 * envelope
            }

            // Channel 0 (Mono)
            channels?[0][frame] = value
            theta += theta_increment
        }

        return buffer
    }

    // Public API for Game Sounds
    func playScoreSound() {
        // High "Ding"
        if let buffer = generateBuffer(freq: 880, duration: 0.15, type: "sine") {
            playerNode.scheduleBuffer(buffer, at: nil, options: [], completionHandler: nil)
            ensurePlaying()
        }
    }

    func playCrashSound() {
        // Low "Buzz/Crash"
        if let buffer = generateBuffer(freq: 100, duration: 0.4, type: "sawtooth") {
            playerNode.scheduleBuffer(buffer, at: nil, options: [], completionHandler: nil)
            ensurePlaying()
        }
    }

    func playStartSound() {
        // "Power Up" - Play two tones
        if let b1 = generateBuffer(freq: 440, duration: 0.1),
            let b2 = generateBuffer(freq: 660, duration: 0.2)
        {

            // Play concurrently or sequence manually?
            // Simple: Play one then schedule other?
            // Actually, playing both works on same node if they overlap? No, node plays queue.
            // Queue them:
            playerNode.scheduleBuffer(b1, at: nil, options: [])
            playerNode.scheduleBuffer(b2, at: nil, options: [], completionHandler: nil)
            ensurePlaying()
        }
    }

    func playWinSound() {
        // "Fanfare" chords
        let freqs: [Float] = [523.25, 659.25, 783.99, 1046.50]  // C Major
        for (i, f) in freqs.enumerated() {
            if let b = generateBuffer(freq: f, duration: 0.4 - Double(i) * 0.05) {
                // Schedule slightly offset? No, simple mix
                playerNode.scheduleBuffer(b, at: nil, options: [], completionHandler: nil)
            }
        }
        ensurePlaying()
    }

    private func ensurePlaying() {
        if !engine.isRunning { try? engine.start() }
        if !playerNode.isPlaying { playerNode.play() }
    }
}
