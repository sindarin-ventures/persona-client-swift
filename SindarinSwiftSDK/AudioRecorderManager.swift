import AVFoundation
import Foundation
import OSLog

/// A protocol for receiving captured audio data in 16-bit format.
protocol AudioRecorderManagerDelegate: AnyObject {
    /// Called whenever a new chunk of 16-bit PCM audio data is captured.
    func didCaptureAudioChunk(_ data: Data)
}

/**
 Manages audio recording using a voice-processing (AEC-enabled) audio unit via `AECAudioStream`.
 */
class AudioRecorderManager: NSObject {

    private let audioSession = AVAudioSession.sharedInstance()

    ///Сustom AECAudioStream for VoiceProcessing I/O
    private var aecAudioStream: AECAudioStream?

    /// A `Task` in which the async for-await loop over audio buffers is running.
    private var recordingTask: Task<Void, Never>?

    /// Indicates whether recording is currently active.
    private(set) var isRecording = false

    /// Desired audio sample rate (Hz). Default is 16 kHz.
    public var sampleRate: Double = 16000.0

    /// Delegate that will receive captured audio data chunks.
    weak var delegate: AudioRecorderManagerDelegate?

    override init() {
        super.init()
        requestPermissionAndSetupSession()
    }

    /**
     Starts recording using `AECAudioStream` in async mode with acoustic echo cancellation enabled.
     */
    func startRecording() {
        guard !isRecording else {
            return
        }

        aecAudioStream = AECAudioStream(
            sampleRate: sampleRate,
            enableRendererCallback: false,
            rendererClosure: nil
        )

        /// Returns an AsyncThrowingStream of AVAudioPCMBuffer
        let stream = aecAudioStream!.startAudioStreamAsync(enableAEC: true)

        print("AEC enabled: \(aecAudioStream?.enableAutomaticEchoCancellation ?? false)")
        print("Stream format: \(String(describing: aecAudioStream?.streamBasicDescription))")

        recordingTask = Task {
            do {
                isRecording = true
                print("Audio recording started with AEC at \(sampleRate) Hz")

                // Capture buffers in an async for-await loop
                for try await buffer in stream {
                    guard let int16Data = self.extractInt16Data(from: buffer) else {
                        continue
                    }
                    // Pass the captured chunk to our delegate
                    self.delegate?.didCaptureAudioChunk(int16Data)
                }
            } catch {
                print("Error while reading audio stream: \(error)")
            }
        }
    }

    /**
     Stops recording by cancelling the Task and disposing of the AECAudioStream.
     */
    func stopRecording() {
        guard isRecording else { return }

        // Cancel the Task to stop capturing
        recordingTask?.cancel()
        recordingTask = nil

        // Stop the audio unit and dispose of resources
        do {
            try aecAudioStream?.stopAudioUnit()
        } catch {
            print("Error while stopping AECAudioStream: \(error)")
        }

        aecAudioStream = nil
        isRecording = false
        print("Recording stopped")
    }

    /**
     Requests permission to record audio and configures the `AVAudioSession` for voice chat.
     */
    private func requestPermissionAndSetupSession() {
        audioSession.requestRecordPermission { [weak self] allowed in
            guard let self = self else { return }
            if allowed {
                do {
                    try self.audioSession.setCategory(.playAndRecord,
                        mode: .voiceChat,
                        options: [.defaultToSpeaker, .allowBluetooth, .duckOthers])
                    try self.audioSession.setActive(true, options: .notifyOthersOnDeactivation)

                    print("Audio session configured for voice chat recording.")
                } catch {
                    print("Error configuring AVAudioSession: \(error)")
                }
            } else {
                print("Recording permission was not granted by the user.")
            }
        }
    }

    /**
     Converts an `AVAudioPCMBuffer` to 16-bit PCM `Data` (mono).
     
     - Parameter buffer: The PCM buffer to extract audio data from.
     - Returns: A `Data` object containing 16-bit PCM samples, or `nil` if format isn't supported.
     */
    private func extractInt16Data(from buffer: AVAudioPCMBuffer) -> Data? {
        let format = buffer.format

        print("----- Buffer info -----")
        print(" Sample Rate: \(format.sampleRate) Hz")
        print(" Channel Count: \(format.channelCount)")
        print(" Common Format: \(format.commonFormat)")
        print(" Interleaved: \(format.isInterleaved ? "YES" : "NO")")
        print(" Frame Length: \(buffer.frameLength)")

        guard let channelData = buffer.int16ChannelData?[0] else {
            print("No Int16 channel data (the format might be unsupported).")
            return nil
        }

        let frameCount = Int(buffer.frameLength)
        let byteCount = frameCount * MemoryLayout<Int16>.size
        print(" Byte Count: \(byteCount)")

        let rawData = Data(bytes: channelData, count: byteCount)

        if byteCount >= 20 {
            let first10Samples = rawData.withUnsafeBytes { rawPtr in
                Array(rawPtr.bindMemory(to: Int16.self).prefix(10))
            }
            print(" First 10 Int16 samples: \(first10Samples)")
        }

        let samples = rawData.withUnsafeBytes { ptr in
            ptr.bindMemory(to: Int16.self)
        }
        let maxSample = samples.max() ?? 0
        let minSample = samples.min() ?? 0
        print("Min sample: \(minSample), Max sample: \(maxSample)")

        print("-----------------------")

        return rawData
    }
}
