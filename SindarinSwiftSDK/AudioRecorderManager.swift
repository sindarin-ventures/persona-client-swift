import AVFoundation
import Foundation
import OSLog

protocol AudioRecorderManagerDelegate: AnyObject {
    func didCaptureAudioChunk(_ data: Data)
}

class AudioRecorderManager: NSObject {

    private let audioSession = AVAudioSession.sharedInstance()

    private var aecAudioStream: AECAudioStream?

    private var recordingTask: Task<Void, Never>?

    private(set) var isRecording = false

    public var sampleRate: Double = 16000.0

    weak var delegate: AudioRecorderManagerDelegate?

    override init() {
        super.init()
        requestPermissionAndSetupSession()
    }

    @available(iOS 15.0, *)
    func startRecording() {
        guard !isRecording else {
            return
        }

        aecAudioStream = AECAudioStream(
            sampleRate: sampleRate,
            enableRendererCallback: false,
            rendererClosure: nil
        )



        let stream = aecAudioStream!.startAudioStreamAsync(enableAEC: true)
        print("Format: \(aecAudioStream?.enableAutomaticEchoCancellation)")
        print("Format: \(aecAudioStream?.streamBasicDescription)")

        recordingTask = Task {
            do {
                isRecording = true
                print("Audio recording started with AEC at \(sampleRate) Hz")

                for try await buffer in stream {
                    guard let int16Data = self.extractInt16Data(from: buffer) else {
                        continue
                    }
                    self.delegate?.didCaptureAudioChunk(int16Data)
                }
            } catch {
                print("Помилка при читанні аудіо-стріму: \(error)")
            }
        }

    }

    func stopRecording() {
        guard isRecording else { return }

        recordingTask?.cancel()
        recordingTask = nil

        do {
            try aecAudioStream?.stopAudioUnit()
        } catch {
            print("Помилка при зупинці AECAudioStream: \(error)")
        }

        aecAudioStream = nil
        isRecording = false
        print("Recording stopped")
    }


    private func requestPermissionAndSetupSession() {
        audioSession.requestRecordPermission { [weak self] allowed in
            guard let self = self else { return }
            if allowed {
                do {
                    try self.audioSession.setCategory(.playAndRecord,
                        mode: .voiceChat,
                        options: [.defaultToSpeaker, .allowBluetooth, .duckOthers])
                    try self.audioSession.setActive(true, options: .notifyOthersOnDeactivation)

                    print("Audio session налаштовано на запис (voiceChat)")
                } catch {
                    print("Помилка налаштування аудіосесії: \(error)")
                }
            } else {
                print("Дозвіл на запис не наданий користувачем.")
            }
        }
    }

    private func extractInt16Data(from buffer: AVAudioPCMBuffer) -> Data? {
        let format = buffer.format

        print("----- Buffer info -----")
        print(" Sample Rate: \(format.sampleRate) Hz")
        print(" Channel Count: \(format.channelCount)")
        print(" Common Format: \(format.commonFormat)")
        print(" Interleaved: \(format.isInterleaved ? "YES" : "NO")")
        print(" Frame Length: \(buffer.frameLength)")

        guard let channelData = buffer.int16ChannelData?[0] else {
            print("Немає Int16 даних (можливо, формат не підтримується)")
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
