import AVFoundation
import Foundation

protocol AudioRecorderManagerDelegate: AnyObject {
    func didCaptureAudioChunk(_ data: Data)
}

class AudioRecorderManager: NSObject, AVAudioRecorderDelegate {
    private var audioRecorder: AVAudioRecorder?
    private var audioSession: AVAudioSession
    private var recordingTimer: Timer?
    private var lastReadPosition: Int64 = 0 // To keep track of the last read position in the file
    weak var delegate: AudioRecorderManagerDelegate?

    override init() {
        self.audioSession = AVAudioSession.sharedInstance()
        super.init()
        requestPermissionAndSetup()
    }

    private func requestPermissionAndSetup() {
        audioSession.requestRecordPermission { [weak self] allowed in
            DispatchQueue.main.async {
                guard let self = self else { return }
                if allowed {
                    self.setupAudioSession()
                    self.setupAudioRecorder()
                } else {
                    print("Recording permission was not granted.")
                    // Handle the failure case here (e.g., show an alert to the user)
                }
            }
        }
    }

    private func setupAudioSession() {
        do {
            try audioSession.setCategory(.playAndRecord, mode: .voiceChat, options: [.duckOthers])
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            print("Failed to setup audio session: \(error)")
        }
    }

    private func setupAudioRecorder() {
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatLinearPCM),
            AVSampleRateKey: 16000,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
        ]

        do {
            audioRecorder = try AVAudioRecorder(url: self.directoryURL(), settings: settings)
            audioRecorder?.delegate = self
        } catch {
            print("Failed to setup audio recorder: \(error)")
        }
    }

    private func directoryURL() -> URL {
        let fileManager = FileManager.default
        let urls = fileManager.urls(for: .documentDirectory, in: .userDomainMask)
        let documentDirectory = urls.first!
        return documentDirectory.appendingPathComponent("userSpeech.wav")
    }

    func startRecording() {
        audioRecorder?.prepareToRecord()
        audioRecorder?.record()
        startRecordingTimer()
    }

    func stopRecording() {
        guard audioRecorder?.isRecording == true else { return }
        audioRecorder?.stop()
        recordingTimer?.invalidate()
        recordingTimer = nil
        lastReadPosition = 0 // Reset the read position

        // Clean up resources after recording is finished
        cleanupAfterRecording()
    }

    private func startRecordingTimer() {
        recordingTimer = Timer.scheduledTimer(
            timeInterval: 0.1, // Possibly reduce interval if necessary
            target: self,
            selector: #selector(readAudioChunk),
            userInfo: nil,
            repeats: true
        )
    }

    @objc private func readAudioChunk() {
        guard let recorder = audioRecorder, recorder.isRecording else { return }
        do {
            let fileHandle = try FileHandle(forReadingFrom: self.directoryURL())
            defer { fileHandle.closeFile() } // Ensure the file is closed even if an error occurs

            fileHandle.seek(toFileOffset: UInt64(lastReadPosition))
            let data = fileHandle.readDataToEndOfFile()
            lastReadPosition += Int64(data.count)

            if !data.isEmpty {
                let int16Data = convertTo16BitPcm(data)
                delegate?.didCaptureAudioChunk(int16Data)
                print("Captured audio chunk")
            }
        } catch {
            print("Failed to read audio data: \(error)")
        }
    }

    private func convertTo16BitPcm(_ data: Data) -> Data {
        // Check if the data needs conversion or if it’s already in the correct format
        guard data.count % MemoryLayout<Int16>.size == 0 else {
            print("Data is not aligned to 16-bit boundaries")
            return Data() // Handle misaligned data
        }

        return data
    }

    private func cleanupAfterRecording() {
        // Optionally remove the recorded file
        do {
            try FileManager.default.removeItem(at: self.directoryURL())
            print("Temporary recorded file removed")
        } catch {
            print("Failed to remove temporary recorded file: \(error)")
        }

        // Optionally reset the audio session if needed
        do {
            try audioSession.setActive(false, options: .notifyOthersOnDeactivation)
            print("Audio session deactivated")
        } catch {
            print("Failed to deactivate audio session: \(error)")
        }
    }

    // AVAudioRecorderDelegate method
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        if flag {
            print("Recording finished successfully")
        } else {
            print("Recording failed or was interrupted")
        }
    }
}
