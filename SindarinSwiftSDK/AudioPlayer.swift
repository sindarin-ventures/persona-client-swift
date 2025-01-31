import AVFoundation
import UIKit

class AudioPlayer: NSObject {
    private var player: AVQueuePlayer?
    private var audioSession: AVAudioSession?
    private var audioQueue: [AVPlayerItem] = []
    private var isPlaying = false

    // Buffer for incoming MP3 data chunks
    private var mp3DataBuffer = Data()
    private let initialBufferThreshold: Int = 20000 // Adjust as necessary
    private var bufferThreshold: Int
    private let maxBufferThreshold: Int = 100000 // Adjust as necessary

    // Timer to handle playing chunks when no new data arrives
    private var bufferTimer: Timer?
    private let bufferTimeout: TimeInterval = 1.0 // Time interval to wait for more data before playing

    // Array to store temporary file URLs for cleanup
    private var temporaryFileURLs: [URL] = []

    override init() {
        bufferThreshold = initialBufferThreshold
        super.init()
        setupAudioSession()
        setupPlayer()
    }

    private func setupAudioSession() {
        audioSession = AVAudioSession.sharedInstance()
        do {
            if let audioSession = audioSession {
                try audioSession.setCategory(.playAndRecord, mode: .voiceChat, options: [.defaultToSpeaker, .allowBluetooth, .duckOthers, ])
                try audioSession.setActive(true)
            } else {
                print("Audio session is not initialized")
            }
        } catch {
            print("Failed to configure audio session: \(error.localizedDescription)")
        }
    }

    private func setupPlayer() {
        player = AVQueuePlayer()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(playerItemDidFinishPlaying(_:)),
            name: .AVPlayerItemDidPlayToEndTime,
            object: nil
        )
    }

    // Add MP3 chunk to the buffer
    func bufferAudio(chunk: Data) {
        mp3DataBuffer.append(chunk)

        // Check if buffer has enough data to start playing
        if mp3DataBuffer.count >= bufferThreshold {
            playAudioFromBuffer()
            // Dynamically increase buffer threshold if necessary
            if bufferThreshold < maxBufferThreshold {
                bufferThreshold += initialBufferThreshold
            }
        } else {
            resetBufferTimer()
        }
    }

    private func playAudioFromBuffer() {
        guard let player = player else { return }

        // Write the buffered data to a temporary file
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".mp3")

        do {
            try mp3DataBuffer.write(to: tempURL)
            let playerItem = AVPlayerItem(url: tempURL)
            audioQueue.append(playerItem)
            player.insert(playerItem, after: nil)

            // Store the temporary file URL for later cleanup
            temporaryFileURLs.append(tempURL)

            // Clear the buffer once data is written to file.
            mp3DataBuffer.removeAll()

            // Start playback if not already playing
            if !isPlaying {
                player.play()
                isPlaying = true
            }
        } catch {
            print("Failed to write MP3 data to file: \(error.localizedDescription)")
        }
    }

    private func resetBufferTimer() {
        bufferTimer?.invalidate()
        bufferTimer = Timer.scheduledTimer(withTimeInterval: bufferTimeout, repeats: false) {
            [weak self] _ in
            self?.playAudioFromBuffer()
        }
    }

    func pauseAudio() {
        player?.pause()
        isPlaying = false
    }

    func resumeAudio() {
        guard !isPlaying else { return }
        player?.play()
        isPlaying = true
    }

    func stop() {
        player?.pause()
        player?.removeAllItems()
        audioQueue.removeAll()
        mp3DataBuffer.removeAll()
        isPlaying = false
        bufferTimer?.invalidate()
        cleanupTemporaryFiles()
    }

    @objc private func playerItemDidFinishPlaying(_ notification: Notification) {
        if let playerItem = notification.object as? AVPlayerItem,
            let index = audioQueue.firstIndex(of: playerItem) {
            audioQueue.remove(at: index)
        }

        if audioQueue.isEmpty {
            isPlaying = false
        }

        // Optionally remove the associated temporary file
        cleanupTemporaryFiles()
    }

    private func cleanupTemporaryFiles() {
        for url in temporaryFileURLs {
            do {
                try FileManager.default.removeItem(at: url)
            } catch {
                print("Failed to delete temporary file: \(error.localizedDescription)")
            }
        }
        temporaryFileURLs.removeAll()
    }
}
